ProjectBootstrap <- R6::R6Class("ProjectBootstrap",
  public = list(
    initialize = function(root) {
      private$root <- normalizePath(root, mustWork = TRUE)
    },
    run = function(args = character(), started = NULL) {
      if (identical(args, "--install")) return(invisible(TRUE))
      private$dependencies()
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
    dependencies = function() {
      packages <- c("R6", "yaml", "jsonlite", "httr2", "DBI", "RSQLite", "digest")
      missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
      if (length(missing)) stop("Dependências ausentes: ", paste(missing, collapse = ", "),
                                ". Execute a instalação indicada no README.", call. = FALSE)
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
