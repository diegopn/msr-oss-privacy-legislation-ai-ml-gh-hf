#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || !args[[1L]] %in% c("tests", "prepare-site")) {
  stop("Informe uma ação interna válida.", call. = FALSE)
}
script <- sub("^--file=", "", commandArgs()[grepl("^--file=", commandArgs())])
root <- if (length(script)) dirname(dirname(normalizePath(script))) else getwd()
bootstrap <- new.env(parent = globalenv())
sys.source(file.path(root, "src/bootstrap.R"), envir = bootstrap)
tryCatch(bootstrap$ProjectBootstrap$new(root)$run_internal(args[[1L]]), error = function(error) {
  message("Execução interrompida: ", conditionMessage(error))
  quit(status = 1L)
})
