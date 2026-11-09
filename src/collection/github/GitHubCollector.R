GitHubCollector <- R6::R6Class("GitHubCollector",
  public = list(
    initialize = function(config, store, http, pilot = FALSE) {
      private$config <- config
      private$store <- store
      private$http <- http
      private$progress <- http$progress
      private$pilot <- pilot
      private$client <- GitHubClient$new(http, config, store)
      private$search <- GitHubSearch$new(http, config, store)
      private$policy <- EligibilityPolicy$new(config)
      private$matcher <- TextMatcher$new(config)
      private$tools <- ProtocolTools$new()
      private$time <- TimePolicy$new(config$settings$protocol$cutoff)
      private$repos <- new.env(parent = emptyenv())
      private$seen <- new.env(parent = emptyenv())
    },
    run = function() {
      private$store$start("github", private$pilot)
      laws <- private$config$settings$protocol$laws
      total <- sum(lengths(lapply(laws, `[[`, "terms")))
      index <- 0L
      for (law in laws) {
        for (term in law$terms) {
          index <- index + 1L
          private$progress$scope(sprintf("Busca %d/%d: %s", index, total, term), term)
          received <- private$search$walk(term, law$start, private$issue,
            private$config$limit("github_results_per_term", private$pilot))
          private$progress$report(paste("Busca", term, "concluída; resultados examinados:", received), counts = FALSE)
        }
      }
      if (!private$pilot) private$recover_pending()
      private$store$finish("completed")
      invisible("completed")
    }
  ),
  private = list(
    config = NULL, store = NULL, http = NULL, pilot = FALSE, client = NULL, search = NULL, policy = NULL,
    matcher = NULL, tools = NULL, time = NULL, repos = NULL, seen = NULL, processed = 0L, progress = NULL,
    repository = function(item) {
      id <- sub("^https://api.github.com/repos/", "", item$repository_url)
      if (exists(id, private$repos, inherits = FALSE)) return(private$repos[[id]])
      repo <- private$client$repository(id)
      if (is.null(repo)) return(NULL)
      decision <- private$policy$assess(repo, repo$ai)
      repo$status <- decision$status
      repo$reason <- decision$reason
      private$store$repository(repo)
      private$repos[[id]] <- repo
      repo
    },
    issue = function(item) {
      key <- private$tools$key("github", "issue", as.character(item$id))
      recovery_key <- key
      private$store$with_recovery_item("issue", recovery_key, list(item = item), function() {
        private$process_issue(item, key, recovering = FALSE)
      })
    },
    process_issue = function(item, key, recovering) {
      if (!recovering && exists(key, private$seen, inherits = FALSE)) return(TRUE)
      if (!recovering) private$seen[[key]] <- TRUE
      if (private$excluded_item(item)) return(TRUE)
      private$process_repository_issue(item, key, recovering)
    },
    process_repository_issue = function(item, key, recovering) {
      repo <- private$repository(item)
      if (is.null(repo)) return(FALSE)
      if (repo$status != "eligible" || (!recovering &&
          private$processed >= private$config$limit("github_issues", private$pilot))) return(TRUE)
      private$collect_issue(item, key, repo)
    },
    collect_issue = function(item, key, repo) {
      private$processed <- private$processed + 1L
      main <- private$artifact(item, repo, key, "issue")
      main$text <- private$tools$text(list(item$title, item$body))
      private$save(main, main$created)
      comments <- private$client$comments(item, private$config$limit("github_comments", private$pilot))
      for (comment in comments) {
        artifact <- private$artifact(comment, repo, key, "comment")
        if (private$time$eligible(artifact$created)) private$save(artifact, main$created)
      }
      complete <- private$confirm(main, comments, item$comments)
      if (complete) private$seen[[key]] <- TRUE
      complete
    },
    excluded_item = function(item) {
      any(c(!is.null(item$pull_request), !identical(item$state, "closed"),
            private$policy$bot(item$user), !private$time$eligible(item$created_at)))
    },
    artifact = function(item, repo, unit_key, kind) {
      list(key = if (kind == "issue") unit_key else private$tools$key("github", kind, as.character(item$id)),
        unit_key = unit_key, repo_key = repo$key, platform = "github", kind = kind,
        created = private$tools$scalar(item$created_at), text = private$tools$scalar(item$body),
        url = private$tools$scalar(item$html_url), metadata = item)
    },
    save = function(artifact, created) {
      private$store$artifact(artifact)
      for (evidence in private$matcher$find(artifact, created)) private$store$evidence(evidence, "github")
    },
    mention_after_cutoff = function(main, comments) {
      laws <- Filter(function(law) private$time$eligible(main$created, law$start), private$config$settings$protocol$laws)
      terms <- unlist(lapply(laws, `[[`, "terms"), use.names = FALSE)
      mentions <- Filter(function(comment) {
        length(private$tools$matches(private$tools$scalar(comment$body), terms, literal = TRUE)) > 0L
      }, comments)
      length(mentions) > 0L && all(vapply(mentions, function(comment) {
        created <- private$time$parse(comment$created_at)
        !is.na(created) && created >= private$time$end
      }, logical(1)))
    },
    confirm = function(main, comments, expected) {
      complete <- length(comments) >= private$tools$scalar(expected, 0L)
      evidence <- private$store$query("SELECT COUNT(*) n FROM evidences WHERE unit_key=? AND kind='legal'",
                                      list(main$key))$n
      if (!complete && !private$pilot) {
        private$store$problem("comments_incomplete", main$url, "Contagem menor que metadados da issue")
      }
      if (complete && evidence == 0L) {
        excluded <- private$mention_after_cutoff(main, comments)
        code <- if (excluded) "search_hit_after_cutoff" else "unconfirmed_search_hit"
        detail <- if (excluded) "Menção apenas em comentário posterior ao corte; excluída do recorte" else "Menção não confirmada dentro do período"
        private$store$problem(code, main$url, detail, resolved = TRUE)
      }
      if (!complete && private$pilot) private$store$problem("pilot_comment_limit", main$url,
                                                          "Comentários limitados pelo piloto", TRUE)
      complete
    },
    recover_pending = function() {
      started_at <- Sys.time()
      started <- private$tools$now()
      initial <- private$store$pending_recovery_items()
      initial_count <- nrow(initial)
      initial_diagnostics <- private$store$problem_count(unresolved_only = TRUE)
      budget <- private$config$settings$http$github_quota_budget
      private$http$recovery_budget(budget)
      on.exit(private$http$recovery_budget(NULL), add = TRUE)

      first_attempted <- 0L
      for (index in seq_len(initial_count)) {
        if (private$http$recovery_time_left() <= 0) break
        private$recover_item(initial[index, , drop = FALSE], 1L)
        first_attempted <- first_attempted + 1L
      }
      after_first <- private$store$pending_recovery_items()
      first_resolved <- private$resolved_count(initial)
      first_created <- max(0L, nrow(after_first) - max(0L, initial_count - first_resolved))

      second_attempted <- 0L
      second_snapshot <- after_first
      private$http$recovery_budget(budget)
      for (index in seq_len(nrow(second_snapshot))) {
        if (private$http$recovery_time_left() <= 0) break
        private$recover_item(second_snapshot[index, , drop = FALSE], 2L)
        second_attempted <- second_attempted + 1L
      }
      final <- private$store$pending_recovery_items()
      second_resolved <- private$resolved_count(second_snapshot)
      second_created <- max(0L, nrow(final) - max(0L, nrow(second_snapshot) - second_resolved))
      summary <- list(run_id = private$store$run_id, initial_pending = as.integer(initial_count),
        initial_diagnostics = as.integer(initial_diagnostics), pass1_attempted = as.integer(first_attempted),
        pass1_resolved = as.integer(first_resolved), pass1_pending = as.integer(nrow(after_first)),
        pass1_created = as.integer(first_created), pass2_attempted = as.integer(second_attempted),
        pass2_resolved = as.integer(second_resolved), pass2_created = as.integer(second_created),
        final_pending = as.integer(nrow(final)), final_diagnostics = as.integer(private$store$problem_count(unresolved_only = TRUE)),
        budget_seconds = as.numeric(budget),
        elapsed_seconds = as.numeric(difftime(Sys.time(), started_at, units = "secs")),
        started = started, finished = private$tools$now())
      private$store$save_recovery_summary(summary)
      private$report_recovery(summary)
      summary
    },
    recover_item = function(row, pass) {
      item_key <- row$item_key[[1L]]
      payload <- private$tools$decode(row$payload[[1L]])
      attempt <- private$store$begin_recovery_attempt(item_key, pass)
      private$progress$activity(sprintf("Recuperação %d/2 | item %d", pass,
        private$store$query("SELECT COUNT(*) n FROM recovery_attempts WHERE run_id=? AND pass=?",
          list(private$store$run_id, pass))$n[[1L]]))
      DBI::dbExecute(private$store$connection,
        "UPDATE problems SET resolved=1 WHERE run_id=? AND recovery_key=? AND resolved=0",
        params = list(private$store$run_id, item_key))
      result <- tryCatch(private$store$with_recovery_item(row$kind[[1L]], item_key, payload, function() {
        if (identical(row$kind[[1L]], "search_window")) {
          private$search$recover(payload, private$issue, Inf)
          TRUE
        } else if (identical(row$kind[[1L]], "issue")) {
          item <- payload$item
          key <- private$tools$key("github", "issue", as.character(item$id))
          private$process_issue(item, key, recovering = TRUE)
        } else FALSE
      }), error = function(error) {
        private$store$problem("recovery_execution_failed", item_key, conditionMessage(error))
        FALSE
      })
      pending_problems <- private$store$query(
        "SELECT COUNT(*) n FROM problems WHERE run_id=? AND recovery_key=? AND resolved=0",
        list(private$store$run_id, item_key))$n[[1L]]
      success <- isTRUE(result) && pending_problems == 0L
      if (!success && pending_problems == 0L) {
        DBI::dbExecute(private$store$connection,
          "UPDATE problems SET resolved=0 WHERE run_id=? AND recovery_key=?",
          params = list(private$store$run_id, item_key))
      }
      if (success) private$store$resolve_recovery_item(item_key) else private$store$keep_recovery_item_pending(item_key)
      private$store$finish_recovery_attempt(attempt, if (success) "resolved" else "pending")
      invisible(success)
    },
    resolved_count = function(items) {
      if (!nrow(items)) return(0L)
      sum(vapply(items$item_key, function(item_key) {
        status <- private$store$query("SELECT status FROM recovery_items WHERE run_id=? AND item_key=?",
          list(private$store$run_id, item_key))$status
        length(status) == 1L && identical(status[[1L]], "resolved")
      }, logical(1)))
    },
    report_recovery = function(summary) {
      metrics <- data.frame(metric = c("Pendências iniciais", "Diagnósticos iniciais",
        "1ª passagem: tentadas / corrigidas / pendentes", "Pendências novas na 1ª passagem",
        "2ª passagem: tentadas / corrigidas / pendentes finais", "Pendências novas na 2ª passagem",
        "Pendências finais", "Diagnósticos finais", "Orçamento por passagem",
        "Tempo total de recuperação", "Resultado"),
        value = c(summary$initial_pending, summary$initial_diagnostics,
          paste(summary$pass1_attempted, summary$pass1_resolved, summary$pass1_pending, sep = " / "),
          summary$pass1_created,
          paste(summary$pass2_attempted, summary$pass2_resolved, summary$final_pending, sep = " / "),
          summary$pass2_created, summary$final_pending, summary$final_diagnostics,
          private$progress$duration(summary$budget_seconds),
          private$progress$duration(summary$elapsed_seconds),
          if (summary$final_diagnostics == 0L) "Concluída" else "Concluída com pendências/inconclusivos"),
        stringsAsFactors = FALSE)
      private$progress$event(paste(c("Recuperação final do GitHub", private$format_recovery_table(metrics)), collapse = "\n"))
    },
    format_recovery_table = function(metrics) {
      widths <- c(max(nchar(c("Métrica", metrics$metric))), max(nchar(c("Resultado", metrics$value))))
      border <- paste0("+", strrep("-", widths[[1L]] + 2L), "+", strrep("-", widths[[2L]] + 2L), "+")
      rows <- vapply(seq_len(nrow(metrics)), function(index) sprintf("| %-*s | %-*s |",
        widths[[1L]], metrics$metric[[index]], widths[[2L]], metrics$value[[index]]), "")
      c(border, sprintf("| %-*s | %-*s |", widths[[1L]], "Métrica", widths[[2L]], "Resultado"),
        border, rows, border)
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
