# languageserver: An implementation of the Language Server Protocol for R

[![R-CMD-check](https://github.com/REditorSupport/languageserver/actions/workflows/rcmdcheck.yml/badge.svg)](https://github.com/REditorSupport/languageserver/actions/workflows/rcmdcheck.yml)
[![codecov](https://codecov.io/gh/REditorSupport/languageserver/graph/badge.svg)](https://app.codecov.io/gh/REditorSupport/languageserver)
[![CRAN\_Status\_Badge](https://www.r-pkg.org/badges/version/languageserver)](https://cran.r-project.org/package=languageserver)
[![CRAN Downloads](https://cranlogs.r-pkg.org/badges/grand-total/languageserver)](https://cran.r-project.org/package=languageserver)
[![r-universe](https://reditorsupport.r-universe.dev/badges/languageserver)](https://reditorsupport.r-universe.dev/#package:languageserver)

`languageserver` is an implementation of the Microsoft's [Language Server Protocol](https://microsoft.github.io/language-server-protocol/) for the language of R.

- [About this fork](#about-this-fork)
- [Installation](#installation)
- [Language Clients](#language-clients)
- [Services Implemented](#services-implemented)
- [Settings](#settings)
- [FAQ](#faq)
  - [Linters](#linters)
  - [Customizing server capabilities](#customizing-server-capabilities)
  - [Customizing formatting style](#customizing-formatting-style)

## About this fork

This repository (`toscm/languageserver`) is a personal fork of [REditorSupport/languageserver](https://github.com/REditorSupport/languageserver).
The changes here are my personal adjustments and will most likely not get merged back into the upstream repository.
This means I can implement things that are useful to me without caring whether they make sense for others.

Differences to upstream:

- Nested package discovery.
  The `r.lsp.nested_packages_depth` setting makes the server scan each workspace folder for R packages in sub-directories and register every package it finds as a workspace of its own, so that a folder containing multiple repositories at once is fully indexed.
  See [Nested R packages](#nested-r-packages) below.

- No semantic tokens for comments.
  Upstream emits a whole-line `comment` semantic token for every comment, which in VS Code overrides the TextMate grammar and destroys the distinct coloring of roxygen tags like `#' @param` and `#' @export`.
  This fork does not emit semantic tokens for comments, so the editor grammar keeps coloring them.

- Four-component version numbers.
  Fork builds use a fourth version component (e.g. `0.3.18.7056`) so they are identifiable at runtime and a plain `install.packages("languageserver")` reads as a downgrade instead of silently replacing the patched package.

## Installation

A few dependencies are required beforehand:

```bash
# On Debian, Ubuntu, etc.
apt install --assume-yes --no-install-recommends build-essential libcurl4-openssl-dev libssl-dev libxml2-dev libuv1-dev r-base

# On Fedora, Centos, etc.
dnf install --assumeyes --setopt=install_weak_deps=False @development-tools libcurl-devel libxml2-devel openssl-devel libuv-devel R

# On Alpine
apk add --no-cache curl-dev g++ gcc libxml2-dev linux-headers make R R-dev
```

`languageserver` is released on CRAN and can be easily installed by

```r
install.packages("languageserver")
```

To try the latest features, install the daily development build from our [r-universe](https://reditorsupport.r-universe.dev) repository:

```r
install.packages("languageserver", repos = c(
    reditorsupport = "https://reditorsupport.r-universe.dev",
    getOption("repos")
))
```

Or install the latest development version from our GitHub repository:

```r
# install.packages("remotes")
remotes::install_github("REditorSupport/languageserver")
```

## Language Clients

The following editors are supported by installing the corresponding extensions:

- VS Code: [vscode-R](https://github.com/REditorSupport/vscode-R)

- Atom: [atom-ide-r](https://github.com/REditorSupport/atom-ide-r)

- Sublime Text: [R-IDE](https://github.com/REditorSupport/sublime-ide-r)

- NeoVim: NeoVim's LSP client with settings

    ```lua
    vim.lsp.config['r_language_server'] = {
    	settings = {
    		filetypes = { "r", "rmd" },
    	},
    }
    vim.api.nvim_create_autocmd("FileType", {
    	pattern = { "r", "rmd" },
    	callback = function()
    		vim.lsp.start(vim.lsp.config["r_language_server"])
    	end,
    }
    ```

  or, if you use [coc.nvim](https://github.com/neoclide/coc.nvim), you can do one of two things:
  
  - Install [coc-r-lsp](https://github.com/neoclide/coc-r-lsp) with:

    ```vim
    :CocInstall coc-r-lsp
    ```

  - or install the languageserver package in R

    ```r
    install.packages("languageserver")
    # or install the developement version
    # remotes::install_github("REditorSupport/languageserver")
    ```

    Then add the following to your Coc config:

    ```json
    "languageserver": {
        "R": {
            "command": "/usr/bin/R",
            "args" : [ "--no-echo", "-e", "languageserver::run()"],
            "filetypes" : ["r"]
        }
    }
    ```

- Emacs: [eglot-mode](https://elpa.gnu.org/devel/doc/eglot.html) (native LSP client)

    ```elisp
    (use-package ess :ensure t)
    (add-hook 'ess-r-mode-hook 'eglot-ensure)
    ```
    To check if it is working, open an R file, place the cursor on a line and run `M-x ess-eval-line`.

- Emacs: [lsp-mode](https://github.com/emacs-lsp/lsp-mode)

- JupyterLab: [jupyterlab-lsp](https://github.com/jupyter-lsp/jupyterlab-lsp)

- [BBEdit](https://www.barebones.com/products/bbedit/): preconfigured in version 14.0 and later; see the [BBEdit LSP support page](https://www.barebones.com/support/bbedit/lsp-notes.html) for complete details.

- [Nova](https://nova.app): [R-Nova](https://github.com/jonclayden/R-Nova)

## Services Implemented

`languageserver` is still under active development, the following services have been implemented:

- [x] [textDocumentSync](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_synchronization)
- [x] [publishDiagnostics](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_publishDiagnostics)
- [x] [hoverProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_hover)
- [x] [completionProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion)
- [x] [completionItemResolve](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#completionItem_resolve)
- [x] [signatureHelpProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_signatureHelp)
- [x] [definitionProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_definition)
- [x] [referencesProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_references)
- [x] [documentHighlightProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentHighlight)
- [x] [documentSymbolProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentSymbol)
- [x] [workspaceSymbolProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_symbol)
- [x] [codeActionProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_codeAction)
- [x] [codeLensProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_codeLens)
- [x] [documentFormattingProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_formatting)
- [x] [documentRangeFormattingProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_rangeFormatting)
- [x] [documentOnTypeFormattingProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_onTypeFormatting)
- [x] [renameProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_rename)
- [x] [prepareRenameProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_prepareRename)
- [x] [documentLinkProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentLink)
- [x] [documentLinkResolve](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#documentLink_resolve)
- [x] [colorProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentColor)
- [x] [colorPresentation](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_colorPresentation)
- [x] [foldingRangeProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_foldingRange)
- [x] [selectionRangeProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_selectionRange)
- [x] [prepareCallHierarchy](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_prepareCallHierarchy)
- [x] [callHierarchyIncomingCalls](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#callHierarchy_incomingCalls)
- [x] [callHierarchyOutgoingCalls](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#callHierarchy_outgoingCalls)
- [x] [prepareTypeHierarchy](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_prepareTypeHierarchy)
- [x] [typeHierarchySupertypes](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#typeHierarchy_supertypes)
- [x] [typeHierarchySubtypes](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#typeHierarchy_subtypes)
- [x] [semanticTokens](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_semanticTokens)
- [x] [linkedEditingRange](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_linkedEditingRange)
- [ ] [executeCommandProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_executeCommand)
- [x] [inlineValueProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_inlineValue)
- [x] [inlayHintProvider](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_inlayHint)

Inline values are a debugger-facing feature rather than normal editor
annotations. When execution is paused, a compatible editor and debug adapter
request variable lookup ranges from the language server, evaluate them in the
selected stack frame, and render the resulting values beside the source. They
have no visible effect when the client or R debug adapter does not request
`textDocument/inlineValue`.

## Settings

`languageserver` exposes the following settings via LSP configuration.

settings | default | description
----     | -----   | -----
`r.lsp.debug`  | `false` | increase verbosity for debug purpose
`r.lsp.log_file` | `null` | file to log debug messages, fallback to stderr if empty
`r.lsp.diagnostics` | `true` | enable file diagnostics via [lintr](https://github.com/r-lib/lintr)
`r.lsp.inlay_hints_minimum_arguments` | `2` | minimum supplied arguments before parameter-name inlay hints are shown
`r.lsp.inlay_hints_minimum_argument_length` | `2` | minimum argument-name length for an inlay hint, excluding an initial `.`
`r.lsp.rich_documentation` | `true` | rich documentation with enhanced markdown features
`r.lsp.snippet_support` | `true` | enable snippets in auto completion
`r.lsp.max_completions` | 200 | maximum number of completion items
`r.lsp.lint_cache` | `false` | toggle caching of lint results
`r.lsp.parse_delay` | `0.15` | seconds to debounce parsing after an edit
`r.lsp.diagnostics_delay` | `0.75` | seconds to debounce diagnostics after the current parse
`r.lsp.parse_cache_max_mb` | `64` | maximum memory used by cached document parse versions
`r.lsp.diagnostics_cache_max_mb` | `16` | maximum memory used by cached diagnostics
`r.lsp.index_mode` | `"auto"` | index R files in the complete workspace; use `"off"` to restore package-only loading
`r.lsp.index_include` | `"**/*.R"` | glob or character vector of globs included in workspace indexing
`r.lsp.index_exclude` | common VCS, dependency, cache, and output directories | glob or character vector of globs excluded from workspace indexing
`r.lsp.index_max_files` | `10000` | maximum number of eligible R files discovered per workspace
`r.lsp.index_max_file_size_mb` | `2` | maximum size of a file included in the workspace index
`r.lsp.index_batch_size` | `20` | maximum number of shallow summaries built in one idle batch
`r.lsp.index_time_budget_ms` | `25` | approximate event-loop budget for each shallow-index batch
`r.lsp.index_persistent_cache` | `true` | persist validated shallow summaries in the user cache directory
`r.lsp.server_capabilities` | `{}` | override server capabilities defined in [capabilities.R](https://github.com/REditorSupport/languageserver/blob/master/R/capabilities.R). See FAQ below.
`r.lsp.link_file_size_limit` | 16384 | maximum file size (in bytes) that supports document links
`r.lsp.nested_packages_depth` | `0` | directory depth to scan below each workspace folder for nested R packages. See FAQ below.

These settings could also specified in `.Rprofile` file via `options(languageserver.<SETTING_NAME> =  <VALUE>)`. For example,

```r
options(languageserver.snippet_support = FALSE)
```

will turn off snippet support globally. LSP configuration settings are always overriden by `options()`.

Project indexing is deliberately two-tiered. Package `R/` files, open files,
and the transitive dependencies of static `source()` or `sys.source()` calls
receive full semantic parsing. Other scripts receive only a lightweight symbol
and source-call summary, so they appear in workspace symbol search without
polluting completion, definition, references, or rename in unrelated scripts.
Static paths built from string literals, `file.path()`, and `here::here()` are
recognized; project code is never executed to resolve a path.

## FAQ

### Nested R packages

By default, a workspace folder is treated as a single workspace, even if it
holds several R packages in sub-directories. The project-wide index still
surfaces symbols from all R files below the folder, but the packages share one
workspace, so they do not get their own document sets, namespace imports, and
diagnostics globals.

Setting `nested_packages_depth` to a positive number makes the server scan each
workspace folder for R packages in sub-directories, and register every package it
finds as a workspace of its own. The value is the maximal directory depth to
descend into:

```r
options(languageserver.nested_packages_depth = 1)
```

With the layout below, a depth of `1` picks up `pkga`, while a depth of `2` is
needed to also pick up `pkgb`:

```
workspace/
├── README.md
├── pkga/            <- depth 1
│   └── DESCRIPTION
└── nested/
    └── pkgb/        <- depth 2
        └── DESCRIPTION
```

Each package is indexed independently, so completions and diagnostics in one
package are not polluted by the symbols of another. Hidden directories and
`renv`, `packrat`, `node_modules`, `revdep`, and `vendor` are never scanned, and
the scan does not descend into a directory that is already a package. Keep the
depth as small as your layout allows, since a large depth on a deep tree makes
startup slower.

The default of `0` preserves the behaviour described in the first paragraph. A
negative value additionally stops the server from indexing a package workspace
at all.

### Linters

With [lintr](https://github.com/r-lib/lintr) v2.0.0, the linters can be specified by creating the `.lintr` file at the project or home directory. Details can be found at lintr [documentation](https://lintr.r-lib.org/articles/lintr.html).

### Customizing server capabilities

Server capabilities are defined in
[capabilities.R](https://github.com/REditorSupport/languageserver/blob/master/R/capabilities.R).
Users could override the capabilities by specifying the LSP configuration setting
`server_capabilities` or
`options(languageserver.server_capabilities)` in `.Rprofile`. For example, to turn off `definitionProvider`, one could either use LSP configuration

```json
"r": {
    "lsp": {
        "server_capabilities": {
            "definitionProvider": false
        }
    }
}
```

or R options

```r
options(
    languageserver.server_capabilities = list(
        definitionProvider = FALSE
    )
)
```

### Customizing formatting style

The language server uses [`styler`](https://github.com/r-lib/styler) to perform code formatting. It uses `styler::tidyverse_style(indent_by = options$tabSize)` as the default style where `options` is the [formatting
options](https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_formatting).

The formatting style can be customized by specifying `languageserver.formatting_style` option which
is supposed to be a function that accepts an `options` argument mentioned above. You could consider to put the code in `.Rprofile`.

[`styler::tidyverse_style`](<https://styler.r-lib.org/reference/tidyverse_style.html>) provides numerous arguments to customize the formatting behavior. For example, to make it only work at indention scope:

```r
options(languageserver.formatting_style = function(options) {
    styler::tidyverse_style(scope = "indention", indent_by = options$tabSize)
})
```

To disable assignment operator fix (replacing `=` with `<-`):

```r
options(languageserver.formatting_style = function(options) {
    style <- styler::tidyverse_style(indent_by = options$tabSize)
    style$token$force_assignment_op <- NULL
    style
})
```

To further customize the formatting style, please refer to [Customizing styler](https://styler.r-lib.org/articles/customizing_styler.html).
