TestRunner <- R6::R6Class("TestRunner",
  public = list(
    initialize = function(config, environment) {
      private$config <- config
      private$environment <- environment
    },
    run = function() {
      files <- list.files(private$config$path("tests"), "\\.R$", full.names = TRUE)
      for (file in files) sys.source(file, private$environment)
      records <- testthat::ListReporter$new()
      reporter <- testthat::MultiReporter$new(list(testthat::SummaryReporter$new(), records))
      testthat::with_reporter(reporter, {
        reporter$start_file("contracts")
        private$environment$ProtocolContractTests$new(private$config, private$environment)$run()
        private$environment$RQ3ContractTests$new(private$config)$run()
        reporter$end_file()
      })
      results <- as.data.frame(records$get_results())
      if (any(results$failed > 0L | results$error)) stop("Testes falharam", call. = FALSE)
      cat(sum(results$passed), "verificações aprovadas em", nrow(results), "contratos offline.\n")
      invisible(results)
    }
  ), private = list(config = NULL, environment = NULL),
  lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
