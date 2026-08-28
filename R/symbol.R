# as defined by the language server protocol
SymbolKind <- list(
    File = 1,
    Module = 2,
    Namespace = 3,
    Package = 4,
    Class = 5,
    Method = 6,
    Property = 7,
    Field = 8,
    Constructor = 9,
    Enum = 10,
    Interface = 11,
    Function = 12,
    Variable = 13,
    Constant = 14,
    String = 15,
    Number = 16,
    Boolean = 17,
    Array = 18,
    Object = 19,
    Key = 20,
    Null = 21,
    EnumMember = 22,
    Struct = 23,
    Event = 24,
    Operator = 25,
    TypeParameter = 26
)

get_document_symbol_kind <- function(type) {
    if (is.character(type) && length(type) == 1) {
        switch(type,
            logical = SymbolKind$Boolean,
            integer = SymbolKind$Number,
            double = SymbolKind$Number,
            complex = SymbolKind$Number,
            character = SymbolKind$String,
            array = SymbolKind$Array,
            list = SymbolKind$Struct,
            `function` = SymbolKind$Function,
            `NULL` = SymbolKind$Null,
            `class` = SymbolKind$Class,
            R6 = SymbolKind$Class,
            S4 = SymbolKind$Class,
            RefClass = SymbolKind$Class,
            SymbolKind$Field
        )
    } else {
        SymbolKind$Field
    }
}

#' Main util function to get document symbols
#' @noRd
get_document_symbols <- function(document, xdoc) {
    if (document$is_rmarkdown) {
        get_rmd_document_sections(document$content)
    } else {
        get_r_document_sections_and_blocks(
            content = document$content, xdoc = xdoc, symbol = TRUE
        )
    }
}

#' Get all the symbols in the document
#' @noRd
document_symbol_reply <- function(id, uri, workspace, document, capabilities) {
    parse_data <- workspace$get_parse_data(uri)
    if (is.null(parse_data) ||
        (!is.null(parse_data$version) && parse_data$version != document$version)) {
        return(NULL)
    }

    defns <- workspace$get_definitions_for_uri(uri)
    logger$info("document definitions found: ", length(defns))
    
    if (isTRUE(capabilities$hierarchicalDocumentSymbolSupport)) {
        # Use hierarchical DocumentSymbol format
        definition_symbols <- lapply(names(defns), function(name) {
            def <- defns[[name]]
            
            # Check if this is a class definition and extract members
            children <- NULL
            if (!is.null(def$type) && def$type %in% c("R6", "S4", "RefClass")) {
                tryCatch({
                    children <- extract_class_members(document, parse_data$xml_doc, def)
                }, error = function(e) {
                    # Silently handle extraction errors
                })
            }
            
            document_symbol(
                name = name,
                kind = get_document_symbol_kind(def$type),
                range = def$range,
                selectionRange = def$range,
                children = children
            )
        })
        
        sections <- get_document_symbols(
            document,
            xdoc = parse_data$xml_doc
        )
        section_symbols <- lapply(sections, function(section) {
            document_symbol(
                name = section$name,
                kind = switch(section$type,
                    section = SymbolKind$Module,
                    chunk = SymbolKind$Key,
                    SymbolKind$Module
                ),
                range = range(
                    start = document$to_lsp_position(
                        row = section$start_line - 1,
                        col = 0
                    ),
                    end = document$to_lsp_position(
                        row = section$end_line - 1,
                        col = nchar(document$line(section$end_line))
                    )
                ),
                selectionRange = range(
                    start = document$to_lsp_position(
                        row = section$start_line - 1,
                        col = 0
                    ),
                    end = document$to_lsp_position(
                        row = section$start_line - 1,
                        col = nchar(document$line(section$start_line))
                    )
                )
            )
        })
        
        result <- nest_document_symbols(c(definition_symbols, section_symbols))
    } else {
        # Use flat SymbolInformation format for backward compatibility
        definition_symbols <- lapply(names(defns), function(name) {
            def <- defns[[name]]
            symbol_information(
                name = name,
                kind = get_document_symbol_kind(def$type),
                location = location(
                    uri = uri,
                    range = def$range
                )
            )
        })
        
        sections <- get_document_symbols(
            document,
            xdoc = parse_data$xml_doc
        )
        section_symbols <- lapply(sections, function(section) {
            symbol_information(
                name = section$name,
                kind = switch(section$type,
                    section = SymbolKind$String,
                    chunk = SymbolKind$Key,
                    SymbolKind$String
                ),
                location = list(
                    uri = uri,
                    range = range(
                        start = document$to_lsp_position(
                            row = section$start_line - 1,
                            col = 0
                        ),
                        end = document$to_lsp_position(
                            row = section$end_line - 1,
                            col = nchar(document$line(section$end_line))
                        )
                    )
                )
            )
        })
        
        result <- c(definition_symbols, section_symbols)
    }

    Response$new(id, result = result)
}

#' Nest document symbols by range containment
#'
#' Sections and definitions are collected as a flat list whose ranges overlap:
#' a section spans every definition written under its heading, and a function
#' can contain sub-sections. Clients such as VS Code only nest what the server
#' nests, so build the tree here: every symbol becomes a child of the innermost
#' symbol whose range contains it, and the top level keeps the rest.
#' Children a symbol already has (e.g. class members) are kept and the nested
#' symbols are appended after them. The output is sorted by position.
#' @noRd
nest_document_symbols <- function(symbols) {
    n <- length(symbols)
    if (n <= 1L) {
        return(symbols)
    }

    start_line <- vapply(symbols, function(s) s$range$start$line, numeric(1))
    start_char <- vapply(symbols, function(s) s$range$start$character, numeric(1))
    end_line <- vapply(symbols, function(s) s$range$end$line, numeric(1))
    end_char <- vapply(symbols, function(s) s$range$end$character, numeric(1))

    # by start ascending, then by end descending, so that a container is
    # visited before everything it contains
    ord <- order(start_line, start_char, -end_line, -end_char)
    symbols <- symbols[ord]
    start_line <- start_line[ord]
    start_char <- start_char[ord]
    end_line <- end_line[ord]
    end_char <- end_char[ord]

    ends_before <- function(i, j) {
        end_line[i] < end_line[j] ||
            (end_line[i] == end_line[j] && end_char[i] <= end_char[j])
    }

    # parent[i] is the index of the innermost container of symbol i, or 0
    parent <- integer(n)
    stack <- integer(0)
    for (i in seq_len(n)) {
        while (length(stack) && !ends_before(i, stack[length(stack)])) {
            stack <- stack[-length(stack)]
        }
        parent[i] <- if (length(stack)) stack[length(stack)] else 0L
        stack <- c(stack, i)
    }

    # attach children bottom-up so nested subtrees are complete before they
    # are attached to their own parent
    for (i in rev(seq_len(n))) {
        children <- which(parent == i)
        if (length(children)) {
            symbols[[i]]$children <- c(symbols[[i]]$children, symbols[children])
        }
    }

    symbols[parent == 0L]
}

#' Get all the symbols in the workspace matching a query
#' @noRd
workspace_symbol_reply <- function(id, workspaces, query) {
    # a nested package workspace overlaps with the project-wide index of the
    # workspace that contains it, so the same definition can be reported by
    # two workspaces and has to be deduplicated
    defns <- list()
    seen <- new.env(hash = TRUE, parent = emptyenv())
    for (workspace in workspaces) {
        for (def in workspace$get_definitions_for_query(query)) {
            key <- paste(
                def$uri, def$name,
                paste(deparse(def$range), collapse = ""),
                sep = "\1"
            )
            if (exists(key, envir = seen, inherits = FALSE)) next
            assign(key, TRUE, envir = seen)
            defns[[length(defns) + 1L]] <- def
        }
    }
    logger$info("workspace symbols found: ", length(defns))
    result <- lapply(defns, function(def) {
        symbol_information(
            name = def$name,
            kind = get_document_symbol_kind(def$type),
            location = location(
                uri = def$uri,
                range = def$range
            )
        )
    })

    Response$new(id, result = result)
}
