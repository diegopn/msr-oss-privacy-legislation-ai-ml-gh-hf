#!/usr/bin/env Rscript

if (getRversion() < numeric_version("4.6.0")) {
  stop("O projeto exige R >= 4.6.0. Versão atual: ", as.character(getRversion()),
       call. = FALSE)
}

started <- as.numeric(Sys.time())
args <- commandArgs(trailingOnly = TRUE)
script <- sub("^--file=", "", commandArgs()[grepl("^--file=", commandArgs())])
root <- if (length(script)) dirname(normalizePath(script)) else getwd()
.libPaths(c(file.path(root, ".Rlibrary"), .libPaths()))
if (!requireNamespace("R6", quietly = TRUE)) {
  if (!identical(args, "--install")) stop("Instale R6: install.packages('R6')", call. = FALSE)
  library_path <- file.path(root, ".Rlibrary")
  dir.create(library_path, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(library_path, .libPaths()))
  install.packages("R6", lib = library_path, repos = "https://cloud.r-project.org")
}
bootstrap <- new.env(parent = globalenv())
sys.source(file.path(root, "src/bootstrap.R"), envir = bootstrap)
tryCatch(bootstrap$ProjectBootstrap$new(root)$run(args, started), error = function(error) {
  message("Execução interrompida: ", conditionMessage(error))
  quit(status = 1L)
})
