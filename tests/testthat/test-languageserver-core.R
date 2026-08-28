BareLanguageServer <- R6::R6Class(
    "BareLanguageServer",
    inherit = LanguageServer,
    private = list(
        close_connection = function(connection) {
            tryCatch({
                if (isOpen(connection)) {
                    close(connection)
                }
            }, error = function(e) NULL)
        },
        finalize = function() {
            private$close_connection(self$inputcon)
            if (!identical(self$outputcon, self$inputcon)) {
                private$close_connection(self$outputcon)
            }
            self$request_callbacks$clear()
        }
    ),
    public = list(
        initialize = function() {
            self$inputcon <- rawConnection(raw(), open = "r+")
            self$outputcon <- textConnection(NULL, open = "w")
            self$exit_flag <- FALSE
            self$pending_replies <- collections::dict()
            self$workspaces <- collections::dict()
            self$workspace_cache <- collections::dict()
            self$workspaces$set(DEFAULT_WORKSPACE, Workspace$new(NULL))
            self$rootUri <- character()
            self$request_callbacks <- collections::dict()
            self$register_handlers()
        },
        close_connections = function() {
            private$finalize()
        }
    )
)

ErrorLanguageServer <- R6::R6Class(
    "ErrorLanguageServer",
    inherit = BareLanguageServer,
    public = list(
        stops = NULL,
        initialize = function() {
            super$initialize()
            self$stops <- new.env(parent = emptyenv())
            self$stops$count <- 0L
            manager <- new.env(parent = baseenv())
            manager$stop <- function() {
                self$stops$count <- self$stops$count + 1L
            }
            self$parse_task_manager <- manager
            self$diagnostics_task_manager <- manager
            self$resolve_task_manager <- manager
        },
        process_events = function() stop("event loop failed")
    )
)

test_that("LanguageServer removes workspaces and preserves open documents", {
    old_diagnostics <- lsp_settings$get("diagnostics")
    withr::defer(lsp_settings$set("diagnostics", old_diagnostics))
    lsp_settings$set("diagnostics", FALSE)
    server <- BareLanguageServer$new()
    withr::defer(server$close_connections())
    root <- withr::local_tempdir()
    uri <- path_to_uri(root)
    workspace <- Workspace$new(root)
    open_uri <- path_to_uri(file.path(root, "open.R"))
    closed_uri <- path_to_uri(file.path(root, "closed.R"))
    open_document <- Document$new(open_uri, content = "open <- TRUE")
    open_document$did_open()
    workspace$documents$set(open_uri, open_document)
    workspace$documents$set(
        closed_uri,
        Document$new(closed_uri, content = "closed <- TRUE")
    )
    server$workspaces$set(uri, workspace)
    server$workspace_cache$set(open_uri, workspace)

    expect_null(server$remove_workspace(character()))
    server$remove_workspace(uri)

    expect_false(server$workspaces$has(uri))
    expect_true(
        server$workspaces$get(DEFAULT_WORKSPACE)$documents$has(open_uri)
    )
    expect_false(
        server$workspaces$get(DEFAULT_WORKSPACE)$documents$has(closed_uri)
    )
    expect_equal(server$workspace_cache$size(), 0L)
})

test_that("LanguageServer detects closed input and reads UTF-8 TCP bytes", {
    server <- BareLanguageServer$new()
    withr::defer(server$close_connections())
    close(server$inputcon)
    server$inputcon <- file(tempfile())
    server$check_connection()
    expect_true(server$exit_flag)

    closed_input <- server$inputcon
    utf8_input <- rawConnection(charToRaw("\u00e9"), open = "rb")
    server$inputcon <- utf8_input
    server$tcp <- TRUE
    expect_equal(server$read_char(2L), "\u00e9")

    server$inputcon <- rawConnection(raw(), open = "r+")
    close(utf8_input)
    close(closed_input)
})

test_that("LanguageServer stops managers after an event loop error", {
    old_log_file <- lsp_settings$get("log_file")
    withr::defer(lsp_settings$set("log_file", old_log_file))
    lsp_settings$set("log_file", withr::local_tempfile())

    server <- ErrorLanguageServer$new()
    withr::defer(server$close_connections())
    expect_null(server$run())
    expect_equal(server$stops$count, 3L)
})

test_that("run configures boolean and file debug modes", {
    old_debug <- lsp_settings$get("debug")
    old_log_file <- lsp_settings$get("log_file")
    withr::defer({
        lsp_settings$set("debug", old_debug)
        lsp_settings$set("log_file", old_log_file)
    })
    fake_server <- new.env(parent = emptyenv())
    fake_server$runs <- 0L
    fake_server$run <- function() {
        fake_server$runs <- fake_server$runs + 1L
    }
    runner <- run
    stub(runner, "LanguageServer$new", function(...) fake_server)

    runner(debug = TRUE)
    expect_true(lsp_settings$get("debug"))
    expect_null(lsp_settings$get("log_file"))

    log_file <- withr::local_tempfile()
    runner(debug = log_file)
    expect_equal(lsp_settings$get("log_file"), log_file)
    expect_equal(fake_server$runs, 2L)
})

# a task manager that only records the parse tasks it is handed
recording_task_manager <- function() {
    manager <- new.env(parent = baseenv())
    manager$tasks <- character()
    manager$add_task <- function(id, task) {
        manager$tasks <- c(manager$tasks, id)
    }
    manager$cancel <- function(id) NULL
    manager$stop <- function() NULL
    manager
}

make_test_package <- function(root, files) {
    dir.create(file.path(root, "R"), recursive = TRUE)
    writeLines(c("Package: testpkg", "Version: 0.1"),
        file.path(root, "DESCRIPTION"))
    writeLines("export(f1)", file.path(root, "NAMESPACE"))
    for (name in files) {
        writeLines(sprintf("%s <- function(x) x", name),
            file.path(root, "R", paste0(name, ".R")))
    }
    invisible(root)
}

test_that("load_workspace loads package files in budgeted steps", {
    old <- list(
        diagnostics = lsp_settings$get("diagnostics"),
        index_persistent_cache = lsp_settings$get("index_persistent_cache")
    )
    withr::defer(for (name in names(old)) lsp_settings$set(name, old[[name]]))
    lsp_settings$set("diagnostics", FALSE)
    lsp_settings$set("index_persistent_cache", FALSE)

    root <- withr::local_tempdir()
    files <- paste0("f", 1:6)
    make_test_package(root, files)

    server <- BareLanguageServer$new()
    withr::defer(server$close_connections())
    server$parse_task_manager <- recording_task_manager()
    server$diagnostics_task_manager <- recording_task_manager()
    server$resolve_task_manager <- recording_task_manager()
    workspace <- Workspace$new(root)
    server$workspaces$set(path_to_uri(root), workspace)

    # scheduling does not load anything yet
    server$load_workspace(workspace)
    expect_true(server$loading_workspaces())
    expect_length(workspace$documents$keys(), 0L)

    # every step does a bounded amount of work; a zero budget still makes
    # progress so that the load cannot stall
    steps <- 0L
    while (server$loading_workspaces()) {
        steps <- steps + 1L
        server$load_workspaces_step(budget_ms = 0)
        expect_lt(steps, 100L)
    }
    expect_gt(steps, 1L)
    expect_setequal(
        basename(vapply(workspace$documents$keys(), path_from_uri, character(1L))),
        paste0(files, ".R")
    )
    expect_length(server$parse_task_manager$tasks, length(files))
    # the index knows the package files and the NAMESPACE was imported
    expect_length(workspace$index$package_source_uris(), length(files))
    expect_false(is.null(workspace$namespace_file_mt))
})

test_that("load_workspace with blocking = TRUE loads everything at once", {
    old <- list(
        diagnostics = lsp_settings$get("diagnostics"),
        index_persistent_cache = lsp_settings$get("index_persistent_cache")
    )
    withr::defer(for (name in names(old)) lsp_settings$set(name, old[[name]]))
    lsp_settings$set("diagnostics", FALSE)
    lsp_settings$set("index_persistent_cache", FALSE)

    root <- withr::local_tempdir()
    make_test_package(root, c("a", "b"))
    server <- BareLanguageServer$new()
    withr::defer(server$close_connections())
    server$parse_task_manager <- recording_task_manager()
    server$diagnostics_task_manager <- recording_task_manager()
    server$resolve_task_manager <- recording_task_manager()
    workspace <- Workspace$new(root)
    server$workspaces$set(path_to_uri(root), workspace)

    server$load_workspace(workspace, blocking = TRUE)
    expect_false(server$loading_workspaces())
    expect_length(workspace$documents$keys(), 2L)

    # rescheduling a loaded workspace restarts its load without duplicates
    server$load_workspaces(blocking = TRUE)
    expect_length(workspace$documents$keys(), 2L)
    expect_false(server$loading_workspaces())
})

test_that("removing a workspace drops its pending load", {
    old <- lsp_settings$get("index_persistent_cache")
    withr::defer(lsp_settings$set("index_persistent_cache", old))
    lsp_settings$set("index_persistent_cache", FALSE)

    root <- withr::local_tempdir()
    make_test_package(root, "a")
    server <- BareLanguageServer$new()
    withr::defer(server$close_connections())
    server$parse_task_manager <- recording_task_manager()
    server$diagnostics_task_manager <- recording_task_manager()
    server$resolve_task_manager <- recording_task_manager()
    uri <- path_to_uri(root)
    workspace <- Workspace$new(root)
    server$workspaces$set(uri, workspace)

    server$load_workspace(workspace)
    expect_true(server$loading_workspaces())
    server$remove_workspace(uri)
    expect_false(server$loading_workspaces())
    expect_false(server$load_workspaces_step())
})
