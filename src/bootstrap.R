ProjectBootstrap <- R6::R6Class("ProjectBootstrap",
  public = list(
    initialize = function(root) {
      private$root <- normalizePath(root, mustWork = TRUE)
      library_path <- file.path(private$root, ".Rlibrary")
      if (dir.exists(library_path)) .libPaths(c(library_path, .libPaths()))
    },
    run = function(args = character(), started = NULL) {
      private$dependencies(args)
      if (identical(args, "--install")) return(invisible(TRUE))
      environment <- new.env(parent = globalenv())
      files <- list.files(file.path(private$root, "src"), "\\.R$", recursive = TRUE,
                          full.names = TRUE)
      files <- files[basename(files) != "bootstrap.R"]
      for (file in sort(files)) sys.source(file, envir = environment)
      env_file <- file.path(private$root, ".env")
      if (file.exists(env_file)) readRenviron(env_file)
      environment$ProjectApplication$new(private$root, environment, started = started)$run(args)
    }
  ),
  private = list(
    root = NULL,
    dependencies = function(args) {
      packages <- c("R6", "yaml", "jsonlite", "httr2", "DBI", "RSQLite", "digest")
      if (identical(args, "--install")) {
        path <- file.path(private$root, ".Rlibrary")
        dir.create(path, recursive = TRUE, showWarnings = FALSE)
        install.packages(c(packages, "testthat", "cyclocomp"), lib = path,
                         repos = "https://cloud.r-project.org")
      }
      missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
      if (length(missing)) stop("Dependências ausentes: ", paste(missing, collapse = ", "),
                                ". Execute a instalação indicada no README.", call. = FALSE)
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
