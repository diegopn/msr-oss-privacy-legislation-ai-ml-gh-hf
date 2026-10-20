ProjectBootstrap <- R6::R6Class("ProjectBootstrap",
  public = list(
    initialize = function(root) {
      private$root <- normalizePath(root, mustWork = TRUE)
    },
    run = function(args = character(), started = NULL) {
      help_requested <- !length(args) || (length(args) == 1L && args[[1L]] %in% c("--help", "-h"))
      environment <- private$load_environment(check_dependencies = !help_requested)
      environment$ProjectApplication$new(private$root, environment, started = started)$run(args)
    },
    run_internal = function(action) {
      if (!action %in% c("tests", "prepare-site")) stop("Ação interna inválida", call. = FALSE)
      packages <- c("R6", "yaml", "jsonlite", "httr2", "DBI", "RSQLite", "digest")
      if (action == "tests") packages <- c(packages, "testthat", "cyclocomp")
      private$dependencies(packages)
      environment <- private$load_environment(check_dependencies = FALSE)
      config <- environment$ProjectConfig$new(private$root)
      if (action == "tests") return(environment$TestRunner$new(config, environment)$run())
      environment$SiteWriter$new(config)$prepare()
    }
  ),
  private = list(
    root = NULL,
    dependencies = function(packages = c("R6", "yaml", "jsonlite", "httr2", "DBI", "RSQLite", "digest")) {
      missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
      if (length(missing)) stop("Dependências ausentes: ", paste(missing, collapse = ", "),
                                ". Consulte a seção de instalação no README.", call. = FALSE)
    },
    load_environment = function(check_dependencies = TRUE) {
      if (check_dependencies) private$dependencies()
      environment <- new.env(parent = globalenv())
      files <- list.files(file.path(private$root, "src"), "\\.R$", recursive = TRUE,
                          full.names = TRUE)
      files <- files[basename(files) != "bootstrap.R"]
      for (file in sort(files)) sys.source(file, envir = environment)
      env_file <- file.path(private$root, ".env")
      if (file.exists(env_file)) readRenviron(env_file)
      environment
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
