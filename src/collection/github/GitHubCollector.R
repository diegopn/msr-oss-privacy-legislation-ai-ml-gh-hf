GitHubCollector <- R6::R6Class("GitHubCollector",
  public = list(
    initialize = function(config, store, http, pilot = FALSE) {
      private$config <- config
      private$store <- store
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
      total <- if (private$pilot) sum(lengths(lapply(laws, `[[`, "terms"))) else length(laws)
      index <- 0L
      for (law in laws) {
        searches <- if (private$pilot) law$terms else list(law$terms)
        for (terms in searches) {
          term <- if (private$pilot) terms else law$id
          index <- index + 1L
          private$progress$scope(sprintf("Busca %d/%d: %s", index, total, term), term)
          received <- private$search$walk(terms, law$start, private$issue,
            private$config$limit("github_results_per_term", private$pilot))
          private$progress$report(paste("Busca", term, "concluída; resultados examinados:", received), counts = FALSE)
        }
      }
      private$store$finish()
    }
  ),
  private = list(
    config = NULL, store = NULL, pilot = FALSE, client = NULL, search = NULL, policy = NULL,
    matcher = NULL, tools = NULL, time = NULL, repos = NULL, seen = NULL, processed = 0L, progress = NULL,
    repository = function(item) {
      id <- sub("^https://api.github.com/repos/", "", item$repository_url)
      if (exists(id, private$repos, inherits = FALSE)) return(private$repos[[id]])
      if (length(ls(private$repos)) >= private$config$limit("github_repositories", private$pilot)) return(NULL)
      repo <- private$client$repository(id)
      decision <- private$policy$assess(repo, repo$ai)
      repo$status <- decision$status
      repo$reason <- decision$reason
      private$store$repository(repo)
      private$repos[[id]] <- repo
      repo
    },
    issue = function(item) {
      key <- private$tools$key("github", "issue", as.character(item$id))
      if (exists(key, private$seen, inherits = FALSE)) return(invisible(NULL))
      private$seen[[key]] <- TRUE
      if (private$excluded_item(item)) return(invisible(NULL))
      repo <- private$repository(item)
      if (is.null(repo) || repo$status != "eligible") return(invisible(NULL))
      if (private$processed >= private$config$limit("github_issues", private$pilot)) return(invisible(NULL))
      private$processed <- private$processed + 1L
      main <- private$artifact(item, repo, key, "issue")
      main$text <- private$tools$text(list(item$title, item$body))
      private$save(main, main$created)
      comments <- private$client$comments(item, private$config$limit("github_comments", private$pilot))
      for (comment in comments) {
        artifact <- private$artifact(comment, repo, key, "comment")
        if (private$time$eligible(artifact$created)) private$save(artifact, main$created)
      }
      private$confirm(main, comments, item$comments)
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
        private$store$problem(code, main$url, detail, resolved = excluded)
      }
      if (!complete && private$pilot) private$store$problem("pilot_comment_limit", main$url,
                                                          "Comentários limitados pelo piloto", TRUE)
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
