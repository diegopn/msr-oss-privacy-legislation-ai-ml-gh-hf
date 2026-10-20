#!/usr/bin/env Rscript

if (getRversion() < numeric_version("4.6.0")) {
  stop("O projeto exige R >= 4.6.0. Versão atual: ", as.character(getRversion()),
       call. = FALSE)
}

started <- as.numeric(Sys.time())
args <- commandArgs(trailingOnly = TRUE)
script <- sub("^--file=", "", commandArgs()[grepl("^--file=", commandArgs())])
root <- if (length(script)) dirname(normalizePath(script)) else getwd()
if (!requireNamespace("R6", quietly = TRUE)) {
  stop("Dependências ausentes. Consulte a seção de instalação no README.",
       call. = FALSE)
}
bootstrap <- new.env(parent = globalenv())
sys.source(file.path(root, "src/bootstrap.R"), envir = bootstrap)
tryCatch(bootstrap$ProjectBootstrap$new(root)$run(args, started), error = function(error) {
  message("Execução interrompida: ", conditionMessage(error))
  quit(status = 1L)
})
