RQ1ContractTests <- R6::R6Class("RQ1ContractTests",
  public = list(
    initialize = function(config) {
      private$config <- config
      private$factory <- FixtureFactory$new(config)
    },
    run = function() {
      private$evidence()
      private$source_roles()
    }
  ),
  private = list(
    config = NULL, factory = NULL,
    evidence = function() testthat::test_that("RQ1 identifica leis e conceitos com limites, origem e corte", {
      matcher <- TextMatcher$new(private$config)
      artifact <- list(key = "a", unit_key = "u", created = "2022-01-01",
        text = "xgDpRy General Data Protection Regulation CCPA CPRA consent consented cookie cookies")
      evidence <- matcher$find(artifact, "2019-01-01")
      laws <- vapply(Filter(function(e) e$kind == "legal", evidence), `[[`, "", "label")
      testthat::expect_equal(sum(laws == "GDPR"), 2L)
      testthat::expect_true("CCPA" %in% laws)
      testthat::expect_false("CPRA" %in% laws)
      concepts <- Filter(function(e) e$kind == "concept", evidence)
      testthat::expect_true(any(vapply(concepts, function(e) e$term == "consent", logical(1))))
      testthat::expect_equal(sum(vapply(concepts, function(e) e$term == "consent", logical(1))), 1L)
      testthat::expect_true(all(vapply(evidence, function(e) nzchar(e$source) && nzchar(e$rule_version), logical(1))))
      artifact$created <- "2026-09-23"
      testthat::expect_length(matcher$find(artifact, "2022-01-01"), 0L)
      artifact$created <- "2022-01-01"
      testthat::expect_false(any(vapply(matcher$find(artifact, ""), function(e) e$kind == "legal", logical(1))))
    }),
    source_roles = function() testthat::test_that("RQ1 separa texto inicial, comentários e contexto de eventos", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("huggingface")
      fixture$store$repository(list(key = "repo", platform = "huggingface", type = "model", id = "org/test",
        status = "eligible", reason = "test", ai = list(signals = list())))
      created <- "2022-01-01T00:00:00Z"
      main <- list(key = "unit", unit_key = "unit", repo_key = "repo", platform = "huggingface",
        kind = "discussion", created = created, text = "Title", url = "url", metadata = list(author = "person"))
      fixture$store$artifact(main)
      events <- list(
        list(key = "e0", type = "title-change", author = "person", date = created, text = "Old title"),
        list(key = "e1", type = "comment", author = "person", date = created, text = "Initial body"),
        list(key = "e2", type = "comment", author = "bot", date = "2022-01-02T00:00:00Z", text = "Automated context"))
      for (event in events) {
        artifact <- main; artifact$key <- event$key; artifact$kind <- "event"
        artifact$created <- event$date; artifact$text <- event$text
        artifact$metadata <- list(type = event$type, author = event$author)
        fixture$store$artifact(artifact)
      }
      sources <- PopulationBuilder$new(fixture$store)$sources("unit")
      roles <- sources$source_role[match(c("unit", "e0", "e1", "e2"), sources$artifact_key)]
      testthat::expect_identical(roles, c("initial_title", "event_context", "initial", "comment_context"))
      testthat::expect_true("Automated context" %in% sources$text)
    })
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
