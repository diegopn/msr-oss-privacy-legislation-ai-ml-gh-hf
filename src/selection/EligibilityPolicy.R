EligibilityPolicy <- R6::R6Class("EligibilityPolicy",
  public = list(
    initialize = function(config) {
      private$time <- TimePolicy$new(config$settings$protocol$cutoff)
      private$license <- LicensePolicy$new(config$osi)
      private$settings <- config$settings$eligibility
    },
    assess = function(repo, ai) {
      reason <- private$exclusion(repo)
      if (nzchar(reason)) return(list(status = "excluded", reason = reason, ai = ai))
      list(status = ai$status, reason = if (ai$status == "review") "insufficient_ai" else "",
           ai = ai)
    },
    bot = function(author, platform = "github") {
      if (identical(tolower(author$type), "bot")) return(TRUE)
      tools <- ProtocolTools$new()
      name <- tolower(tools$scalar(author$login, tools$scalar(author$name)))
      known <- identical(platform, "huggingface") && name %in% tolower(unlist(private$settings$hf_bot_accounts, use.names = FALSE))
      known || grepl("\\[bot\\]|(^|[-_])bot($|[-_])", name, perl = TRUE)
    }
  ),
  private = list(
    time = NULL, license = NULL, settings = NULL,
    exclusion = function(repo) {
      reasons <- c(unavailable = !isTRUE(repo$available),
        visibility_unknown_or_private = !identical(repo$private, FALSE),
        disabled = isTRUE(repo$disabled),
        gated_or_unknown = identical(repo$platform, "huggingface") && !identical(repo$gated, FALSE),
        outside_period_or_invalid_date = !private$time$eligible(repo$created),
        license_not_approved = !private$license$accepts(repo$license),
        fork = !private$settings$accept_forks && isTRUE(repo$fork),
        archived = !private$settings$accept_archived && isTRUE(repo$archived))
      excluded <- names(reasons)[reasons]
      if (!length(excluded)) return("")
      excluded[[1L]]
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
