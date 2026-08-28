# languageserver

[![R-CMD-check](https://github.com/toscm/languageserver/actions/workflows/rcmdcheck.yml/badge.svg)](https://github.com/toscm/languageserver/actions/workflows/rcmdcheck.yml)

This is a personal fork of [REditorSupport/languageserver](https://github.com/REditorSupport/languageserver), the R implementation of the Language Server Protocol, that implements the following improvements:

- 0.3.18.7060: Parse every file exactly once during startup: nested package files are loaded only in their own workspace ([46db128](https://github.com/toscm/languageserver/commit/46db128)) and the index summary is built from the worker's parse result instead of parsing again in the main process ([20ce56d](https://github.com/toscm/languageserver/commit/20ce56d)).
- 0.3.18.7060: Fix "argument `rootPath` is missing" errors in call hierarchy, rename and references ([30d38e8](https://github.com/toscm/languageserver/commit/30d38e8)).
- 0.3.18.7059: Load workspaces incrementally between requests instead of blocking the server for tens of seconds after startup, and make file discovery about ten times faster ([cea5007](https://github.com/toscm/languageserver/commit/cea5007)).
- 0.3.18.7059: Nest sections and definitions in the document outline so that `# Fit ####` headings contain the functions written under them, shown as collapsible headings in VS Code ([8470400](https://github.com/toscm/languageserver/commit/8470400)).
- 0.3.18.7057: Fix syntax highlighting of roxygen comments in VS Code by no longer emitting semantic tokens for comments ([0ec4f6e](https://github.com/toscm/languageserver/commit/0ec4f6e)).
- 0.3.18.7056: Support folders containing multiple R packages through the `nested_packages_depth` setting ([f5ea4b8](https://github.com/toscm/languageserver/commit/f5ea4b8)).

Install the fork with `devtools::install_github("toscm/languageserver")`.
