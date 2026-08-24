# languageserver

[![R-CMD-check](https://github.com/toscm/languageserver/actions/workflows/rcmdcheck.yml/badge.svg)](https://github.com/toscm/languageserver/actions/workflows/rcmdcheck.yml)

This is a personal fork of [REditorSupport/languageserver](https://github.com/REditorSupport/languageserver), the R implementation of the Language Server Protocol, that implements the following improvements:

- 0.3.18.7057: Fix syntax highlighting of roxygen comments in VS Code by no longer emitting semantic tokens for comments ([0ec4f6e](https://github.com/toscm/languageserver/commit/0ec4f6e)).
- 0.3.18.7056: Support folders containing multiple R packages through the `nested_packages_depth` setting ([f5ea4b8](https://github.com/toscm/languageserver/commit/f5ea4b8)).

Install the fork with `devtools::install_github("toscm/languageserver")`.
