ProtocolContractTests <- R6::R6Class("ProtocolContractTests",
  public = list(
    initialize = function(config, environment) {
      private$config <- config
      private$environment <- environment
      private$factory <- FixtureFactory$new(config)
    },
    run = function() {
      private$configuration()
      private$time()
      private$license()
      private$ai()
      private$text()
      private$http()
      private$pagination()
      private$hf_throttle()
      private$search()
      private$search_last_page()
      private$search_overlap()
      private$search_unresolved()
      private$search_gap_handling()
      private$search_invalid_pages()
      private$acquisition_gaps()
      private$collectors()
      private$collection_optimization()
      private$collection_recovery()
      private$hf_recovery()
      private$github_cutoff()
      private$hf_filters()
      private$pilot_limits()
      private$unavailability()
      private$storage()
      private$pilot_retention()
      private$sampling()
      private$coding()
      private$analysis()
      private$pipeline()
      private$application()
      private$progress()
      private$structure()
    }
  ),
  private = list(
    config = NULL, environment = NULL, factory = NULL,
    configuration = function() testthat::test_that("protocolo e fontes permanecem explícitos", {
      c <- private$config
      testthat::expect_length(c$settings$protocol$laws, 4L)
      testthat::expect_length(c$settings$ai$topics, 24L)
      testthat::expect_equal(sum(lengths(lapply(c$settings$protocol$laws, `[[`, "terms"))), 7L)
      testthat::expect_length(c$concepts$concepts, 20L)
      testthat::expect_length(c$taxonomy$categories, 24L)
      testthat::expect_true(all(c$reference_status()))
      testthat::expect_silent(c$require_references())
      testthat::expect_equal(c$limit("github_comments", TRUE), 20L)
      testthat::expect_equal(c$limit("github_comments", FALSE), Inf)
      testthat::expect_equal(unlist(c$settings$pilot, use.names = FALSE), c(100, 20, 100, 20, 50, 10, 20))
      source <- jsonlite::fromJSON(c$path("inputs/reference/replication/manifest.json"))
      for (i in seq_len(nrow(source$files))) {
        testthat::expect_identical(digest::digest(file = c$path(source$files$local[i]), algo = "sha256", serialize = FALSE), source$files$sha256[i])
      }
    }),
    time = function() testthat::test_that("datas são estritas e o corte inclui o último dia", {
      time <- TimePolicy$new("2026-09-22")
      testthat::expect_true(time$eligible("2026-09-22T23:59:59.999Z"))
      testthat::expect_false(time$eligible("2026-09-23T00:00:00Z"))
      testthat::expect_true(time$eligible("2026-09-22T20:59:59-03:00"))
      testthat::expect_false(time$eligible("2026-09-22T21:00:00-03:00"))
      for (date in list(NULL, "", NA, "2026-02-30", "2026-01-01T00:00:00", "2026-01-01garbage", "2026-01-01T00:00:00+99:00")) {
        testthat::expect_false(time$eligible(date))
      }
      testthat::expect_true(time$eligible("2016-04-14", "2016-04-14"))
      testthat::expect_false(time$eligible("2016-04-13T23:59:59Z", "2016-04-14"))
    }),
    license = function() testthat::test_that("todos os identificadores SPDX precisam ser OSI", {
      policy <- LicensePolicy$new(private$config$osi)
      for (value in c("MIT", "MIT OR Apache-2.0", "(MIT AND Apache-2.0) OR BSD-3-Clause")) testthat::expect_true(policy$accepts(value))
      for (value in c("", "NOASSERTION", "MIT OR LicenseRef-Proprietary", "MIT OR", "(MIT", "MIT Apache-2.0", "mit", "MIT WITH NotAnException")) testthat::expect_false(policy$accepts(value))
      testthat::expect_false(policy$accepts(NULL))
      testthat::expect_true(policy$accepts(policy$canonical("mit OR apache-2.0")))
    }),
    ai = function() testthat::test_that("IA exige descoberta e prova técnica no GitHub e estrutura no Hub", {
      classifier <- AIClassifier$new(private$config)
      metadata <- list(name = "demo", topics = list("machine-learning"))
      testthat::expect_identical(classifier$github(metadata)$status, "review")
      testthat::expect_identical(classifier$github(metadata, list("requirements.txt" = "torch>=2"))$status, "eligible")
      testthat::expect_identical(classifier$github(list(name = "demo"), list("requirements.txt" = "torch"))$status, "review")
      testthat::expect_identical(classifier$github(metadata, list("requirements.txt" = "array"))$status, "review")
      testthat::expect_identical(classifier$github(metadata, code = list("model.py" = "fit(x); predict(x)"))$status, "eligible")
      testthat::expect_identical(classifier$github(metadata, code = list("model.py" = "fit(x)"))$status, "review")
      testthat::expect_identical(classifier$huggingface(list(tags = list("machine-learning", "transformers")))$status, "review")
      testthat::expect_identical(classifier$huggingface(list(cardData = list(description = "transformers")))$status, "review")
      testthat::expect_identical(classifier$huggingface(list(pipeline_tag = "text-generation"))$status, "eligible")
      testthat::expect_identical(classifier$huggingface(list(), list(task_categories = list("text-classification")))$status, "eligible")
      policy <- EligibilityPolicy$new(private$config)
      repo <- list(platform = "github", private = FALSE, available = TRUE, created = "2020-01-01", license = "MIT", fork = TRUE, archived = TRUE)
      testthat::expect_identical(policy$assess(repo, list(status = "eligible"))$status, "eligible")
      repo$private <- NULL
      testthat::expect_identical(policy$assess(repo, list(status = "eligible"))$reason, "visibility_unknown_or_private")
      repo$private <- FALSE; repo$platform <- "huggingface"; repo$gated <- "auto"
      testthat::expect_identical(policy$assess(repo, list(status = "eligible"))$reason, "gated_or_unknown")
      testthat::expect_true(policy$bot(list(type = "Bot", login = "person")))
      testthat::expect_true(policy$bot(list(type = "User", login = "build-bot")))
      testthat::expect_false(policy$bot(list(type = "User", login = "robotics")))
    }),
    text = function() testthat::test_that("leis são literais e conceitos respeitam limites e origem", {
      matcher <- TextMatcher$new(private$config)
      artifact <- list(key = "a", unit_key = "u", created = "2022-01-01", text = "xgDpRy General Data Protection Regulation CCPA CPRA consent consented cookie cookies")
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
    http = function() {
      private$http_retries()
      private$http_quotas()
    },
    http_retries = function() testthat::test_that("HTTP preserva respostas e limita falhas transitórias", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("github")
      calls <- 0L
      transport <- function(url, headers, timeout) {
        calls <<- calls + 1L
        testthat::expect_equal(timeout, 30)
        private$factory$response(list(ok = TRUE), if (calls < 3L) 503L else 200L)
      }
      http <- private$factory$http(fixture, "github", transport)
      testthat::expect_true(http$get("https://api.github.com/test")$data$ok)
      testthat::expect_equal(calls, 3L)
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM responses")$n, 3L)
      for (path in fixture$store$query("SELECT path FROM responses")$path) testthat::expect_true(file.exists(fixture$config$path(path)))
      classed <- private$factory$http(fixture, "github", function(url, headers, timeout) {
        response <- private$factory$response(list(ok = TRUE))
        response$headers <- structure(response$headers, class = "httr2_headers")
        response
      })
      testthat::expect_true(classed$get("https://api.github.com/classed-headers")$data$ok)
      testthat::expect_match(tail(fixture$store$query("SELECT headers FROM responses")$headers, 1L), "content-type")
      mixed <- private$factory$http(fixture, "huggingface", function(url, headers, timeout) list(
        status = 200L, headers = list(`content-type` = "text/markdown; charset=utf-8"),
        body = c(charToRaw("---\nlicense: mit\n---\n"), as.raw(c(0x68, 0, 0x69, 0)))))
      testthat::expect_match(mixed$get("https://huggingface.co/card")$text, "license: mit")
      calls <- 0L
      failing <- private$factory$http(fixture, "github", function(url, headers, timeout) {
        calls <<- calls + 1L; private$factory$response(status = 503L)
      })
      testthat::expect_null(failing$get("https://api.github.com/fail"))
      testthat::expect_equal(calls, 5L)
      forbidden <- private$factory$http(fixture, "github", function(url, headers, timeout) private$factory$response(status = 403L))
      testthat::expect_null(forbidden$get("https://api.github.com/forbidden"))
      invalid_json <- private$factory$http(fixture, "github", function(url, headers, timeout) list(
        status = 200L, headers = list(`content-type` = "application/json"), body = charToRaw("{")))
      testthat::expect_null(invalid_json$get("https://api.github.com/invalid-json"))
      testthat::expect_true(all(c("http_failure", "invalid_json") %in%
        fixture$store$query("SELECT code FROM problems")$code))
      testthat::expect_null(http$get("https://attacker.test/next"))
      testthat::expect_true("invalid_cursor" %in% fixture$store$query("SELECT code FROM problems")$code)
    }),
    http_quotas = function() testthat::test_that("cotas usam headers, orçamento e repetições independentes", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("huggingface")
      calls <- 0L; waits <- numeric(); now <- 0
      transport <- function(url, headers, timeout) {
        calls <<- calls + 1L
        private$factory$response(list(ok = TRUE), if (calls %% 2L == 1L) 429L else 200L,
          list(ratelimit = '"api";r=0;t=12'))
      }
      http <- HttpClient$new("huggingface", fixture$config, fixture$store, transport,
        function() now, function(seconds) { waits <<- c(waits, seconds); now <<- now + seconds })
      testthat::expect_true(http$get("https://huggingface.co/api/test")$data$ok)
      testthat::expect_true(any(waits >= 13))
      now <- 4000
      testthat::expect_true(http$get("https://huggingface.co/api/test2")$data$ok)
      quota <- private$factory$http(fixture, "huggingface", function(url, headers, timeout) private$factory$response(status = 429L))
      testthat::expect_null(quota$get("https://huggingface.co/api/quota"))
      gh_calls <- 0L; now <- 0
      gh <- HttpClient$new("github", fixture$config, fixture$store, function(url, headers, timeout) {
        gh_calls <<- gh_calls + 1L
        private$factory$response(list(ok = TRUE), if (gh_calls %% 2L == 1L) 403L else 200L,
          list(`x-ratelimit-remaining` = "0", `x-ratelimit-reset` = "20"))
      }, function() now, function(seconds) now <<- now + seconds)
      testthat::expect_true(gh$get("https://api.github.com/search/issues", "search")$data$ok)
      now <- 22000
      testthat::expect_null(gh$get("https://api.github.com/search/issues", "search"))
    }),
    pagination = function() testthat::test_that("paginação continua além de 100 e rejeita cursores repetidos", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("huggingface")
      transport <- function(url, headers, timeout) {
        if (endsWith(url, "page=2")) return(private$factory$response(list(list(id = "last"))))
        private$factory$response(lapply(1:100, function(i) list(id = i)), headers = list(link = '<https://huggingface.co/api/test?page=2>; rel="next"'))
      }
      pages <- Pagination$new(private$factory$http(fixture, "huggingface", transport), fixture$store)
      testthat::expect_length(pages$collect("https://huggingface.co/api/test"), 101L)
      testthat::expect_length(pages$collect("https://huggingface.co/api/test", limit = 50), 50L)
      repeated <- private$factory$http(fixture, "huggingface", function(url, headers, timeout)
        private$factory$response(list(list(id = 1L)), headers = list(link = '<https://huggingface.co/api/repeat>; rel="next"')))
      testthat::expect_length(Pagination$new(repeated, fixture$store)$collect("https://huggingface.co/api/repeat"), 1L)
      testthat::expect_null(pages$next_url('broken; rel="next"'))
      testthat::expect_true(all(c("repeated_cursor", "invalid_cursor") %in%
        fixture$store$query("SELECT code FROM problems")$code))
    }),
    hf_throttle = function() testthat::test_that("descoberta e páginas de Discussions respeitam o intervalo HF", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("huggingface")
      now <- 0; times <- numeric()
      transport <- function(url, headers, timeout) {
        times <<- c(times, now)
        if (grepl("/api/models?", url, fixed = TRUE)) {
          if (grepl("page=2", url, fixed = TRUE)) return(private$factory$response(list(list(id = "last"))))
          return(private$factory$response(list(list(id = "first")), headers = list(link =
            '<https://huggingface.co/api/models?page=2>; rel="next"')))
        }
        start <- if (grepl("p=1", url, fixed = TRUE)) 1L else 0L
        private$factory$response(list(start = start, count = 2L, discussions = list(list(num = start + 1L))))
      }
      http <- HttpClient$new("huggingface", fixture$config, fixture$store, transport,
        function() now, function(seconds) now <<- now + seconds)
      client <- HuggingFaceClient$new(http, fixture$config, fixture$store)
      client$walk_discovery("model", "mit", function(item) TRUE)
      client$discussions(list(type = "model", id = "org/demo"))
      testthat::expect_equal(length(times), 4L)
      testthat::expect_true(all(diff(times) >= fixture$config$settings$http$hf_intervals$pages))
    }),
    search = function() testthat::test_that("intervalos saturados são subdivididos e lacunas locais não interrompem a busca", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("github")
      saturated <- private$factory$http(fixture, "github", function(url, headers, timeout)
        private$factory$response(list(total_count = 1001L, incomplete_results = FALSE, items = list())))
      search <- GitHubSearch$new(saturated, fixture$config, fixture$store)
      testthat::expect_identical(search$walk("GDPR", "2026-09-22T23:59:58Z", function(item) NULL), 0L)
      testthat::expect_true("search_saturated_second" %in% fixture$store$query("SELECT code FROM problems")$code)
      count <- 0L
      paged <- private$factory$http(fixture, "github", function(url, headers, timeout) {
        ids <- if (endsWith(url, "page=1")) 1:100 else 101:150
        link <- if (endsWith(url, "page=1")) paste0('<', sub("&page=1$", "&page=2", url), '>; rel="next"') else NULL
        private$factory$response(list(total_count = 150L, incomplete_results = FALSE,
          items = lapply(ids, function(i) list(id = i))), headers = list(link = link))
      })
      GitHubSearch$new(paged, fixture$config, fixture$store)$walk("GDPR", "2026-09-22", function(item) count <<- count + 1L)
      testthat::expect_equal(count, 150L)
      count <- 0L
      GitHubSearch$new(paged, fixture$config, fixture$store)$walk("GDPR", "2026-09-22", function(item) count <<- count + 1L, limit = 100)
      testthat::expect_equal(count, 100L)
    }),
    search_last_page = function() testthat::test_that("a busca reconcilia 949 resultados com 948 itens sem solicitar a página 11", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("github")
      full_range <- "created:2026-09-22T23:59:58Z..2026-09-22T23:59:59Z"
      left_range <- "created:2026-09-22T23:59:58Z..2026-09-22T23:59:58Z"
      for (mode in c("last", "over_limit", "absent")) {
        requests <- character(); ids <- integer()
        transport <- function(url, headers, timeout) {
          requests <<- c(requests, url)
          page <- as.integer(sub(".*&page=", "", url))
          if (page > 10L) return(private$factory$response(list(message = "Only the first 1000 search results are available"), status = 422L))
          parent <- grepl(full_range, utils::URLdecode(url), fixed = TRUE)
          pool <- if (parent) 1:948 else if (grepl(left_range, utils::URLdecode(url), fixed = TRUE)) 1:474 else 475:949
          total <- if (parent) 949L else length(pool)
          first <- if (parent && page > 1L) (page - 1L) * 100L else (page - 1L) * 100L + 1L
          last <- min(if (parent) page * 100L - 1L else page * 100L, length(pool))
          next_page <- page * 100L < total || (parent && mode == "over_limit")
          link <- if (next_page) paste0('<', sub("&page=[0-9]+$", paste0("&page=", page + 1L), url), '>; rel="next"') else
            paste0('<', sub("&page=[0-9]+$", "&page=1", url), '>; rel="first"')
          response_headers <- if (parent && mode == "absent") list() else list(link = link)
          private$factory$response(list(total_count = total, incomplete_results = FALSE,
            items = lapply(pool[first:last], function(id) list(id = id))), headers = response_headers)
        }
        search <- GitHubSearch$new(private$factory$http(fixture, "github", transport), fixture$config, fixture$store)
        received <- search$walk("GDPR", "2026-09-22T23:59:58Z", function(item) ids <<- c(ids, item$id))
        testthat::expect_equal(received, 949L, info = mode)
        testthat::expect_identical(sort(ids), 1:949, info = mode)
        testthat::expect_equal(anyDuplicated(ids), 0L, info = mode)
        testthat::expect_false(any(endsWith(requests, "&page=11")), info = mode)
        parent_pages <- requests[grepl(full_range, utils::URLdecode(requests), fixed = TRUE)]
        testthat::expect_length(parent_pages, if (mode == "absent") 1L else 10L)
        testthat::expect_length(requests, if (mode == "absent") 11L else 20L)
        requests <- character(); ids <- integer()
        testthat::expect_equal(search$walk("GDPR", "2026-09-22T23:59:58Z", function(item) ids <<- c(ids, item$id), limit = 100L), 100L)
        testthat::expect_identical(ids, 1:100)
        testthat::expect_false(any(endsWith(requests, "&page=11")))
      }
      testthat::expect_length(fixture$store$query("SELECT code FROM problems")$code, 0L)
    }),
    search_overlap = function() testthat::test_that("repetições e mudanças de total entre páginas não mascaram uma busca incompleta", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("github")
      for (mode in c("overlap", "changed_total")) {
        requests <- character(); ids <- integer()
        expected <- if (mode == "overlap") 150L else 151L
        transport <- function(url, headers, timeout) {
          requests <<- c(requests, url)
          query <- utils::URLdecode(url)
          parent <- grepl("23:59:58Z..2026-09-22T23:59:59Z", query, fixed = TRUE)
          first_page <- endsWith(url, "page=1")
          pool <- if (parent) {
            if (first_page) 1:100 else if (mode == "overlap") 100:149 else 101:150
          } else if (grepl("created:2026-09-22T23:59:58Z", query, fixed = TRUE)) 1:75 else 76:expected
          total <- if (parent) { if (first_page) 150L else expected } else length(pool)
          link <- if (parent && first_page) paste0('<', sub("&page=1$", "&page=2", url), '>; rel="next"') else NULL
          private$factory$response(list(total_count = total, incomplete_results = FALSE,
            items = lapply(pool, function(id) list(id = id))), headers = list(link = link))
        }
        search <- GitHubSearch$new(private$factory$http(fixture, "github", transport), fixture$config, fixture$store)
        testthat::expect_equal(search$walk("GDPR", "2026-09-22T23:59:58Z", function(item) ids <<- c(ids, item$id)), expected)
        testthat::expect_identical(sort(ids), seq_len(expected))
        testthat::expect_length(requests, 4L)
      }
    }),
    search_unresolved = function() testthat::test_that("divergência irredutível vira lacuna local sem interromper a busca", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("github")
      requests <- character(); ids <- integer()
      transport <- function(url, headers, timeout) {
        requests <<- c(requests, url)
        private$factory$response(list(total_count = 2L, incomplete_results = FALSE, items = list(list(id = 1L))))
      }
      http <- private$factory$http(fixture, "github", transport)
      events <- character()
      http$progress <- ConsoleProgress$new(terminal = FALSE, write = function(text) events <<- c(events, text))
      search <- GitHubSearch$new(http, fixture$config, fixture$store)
      testthat::expect_identical(search$walk("GDPR", "2026-09-22T23:59:58Z", function(item) ids <<- c(ids, item$id)), 0L)
      testthat::expect_length(requests, 3L)
      testthat::expect_length(ids, 0L)
      testthat::expect_false(any(grepl("divergente|vazia persistente|um segundo", events)))
      testthat::expect_identical(fixture$store$query("SELECT code FROM problems")$code, rep("search_saturated_second", 2L))
    }),
    search_gap_handling = function() testthat::test_that("intervalos sem resposta verificável ficam registrados sem bloquear a análise", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("github")
      events <- character(); requests <- 0L
      http <- private$factory$http(fixture, "github", function(url, headers, timeout) {
        requests <<- requests + 1L
        private$factory$response(list(total_count = 1L, incomplete_results = FALSE, items = list()))
      })
      http$progress <- ConsoleProgress$new(terminal = FALSE, write = function(text) events <<- c(events, text))
      search <- GitHubSearch$new(http, fixture$config, fixture$store)
      testthat::expect_identical(search$walk("GDPR", "2026-09-22T23:59:58Z", function(item) NULL), 0L)
      testthat::expect_equal(requests, 6L)
      testthat::expect_length(events, 0L)
      codes <- fixture$store$query("SELECT code FROM problems WHERE run_id=? ORDER BY problem_id", list(fixture$store$run_id))$code
      testthat::expect_identical(codes, rep("search_empty_second", 2L))
      testthat::expect_identical(fixture$store$finish(), "completed")
      testthat::expect_identical(fixture$store$query("SELECT status FROM runs WHERE run_id=?", list(fixture$store$run_id))$status, "completed")
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM problems WHERE run_id=? AND resolved=0", list(fixture$store$run_id))$n, 2L)
      fixture$store$start("huggingface")
      fixture$store$problem("http_failure", "https://huggingface.co", "HTTP 503")
      testthat::expect_identical(fixture$store$finish(), "completed")
    }),
    search_invalid_pages = function() testthat::test_that("páginas inválidas são registradas e descartadas sem interromper outras buscas", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      cases <- list(
        repeated = list(total_count = 150L, incomplete_results = FALSE, items = lapply(1:100, function(id) list(id = id))),
        empty = list(total_count = 150L, incomplete_results = FALSE, items = list()),
        incomplete = list(total_count = 150L, incomplete_results = TRUE, items = list(list(id = 101L))),
        invalid = list(items = list(list(id = 101L))))
      for (name in names(cases)) {
        fixture$store$start("github")
        ids <- integer()
        transport <- function(url, headers, timeout) {
          if (endsWith(url, "page=2")) return(private$factory$response(cases[[name]]))
          private$factory$response(list(total_count = 150L, incomplete_results = FALSE,
            items = lapply(1:100, function(id) list(id = id))), headers = list(link =
              paste0('<', sub("&page=1$", "&page=2", url), '>; rel="next"')))
        }
        search <- GitHubSearch$new(private$factory$http(fixture, "github", transport), fixture$config, fixture$store)
        testthat::expect_silent(search$walk("GDPR", "2026-09-22", function(item) ids <<- c(ids, item$id)))
        testthat::expect_length(ids, 0L)
        testthat::expect_identical(fixture$store$query("SELECT code FROM problems WHERE run_id=?", list(fixture$store$run_id))$code,
          if (name == "incomplete") "incomplete_search_page" else "invalid_search_page")
      }
    }),
    acquisition_gaps = function() testthat::test_that("falhas HTTP e respostas inválidas não bloqueiam coleta nem análise", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("github")
      mock <- MockHubTransport$new(private$factory)
      search_failed <- FALSE
      http <- private$factory$http(fixture, "github", function(url, headers, timeout) {
        if (!search_failed && grepl("/search/issues?", url, fixed = TRUE)) {
          search_failed <<- TRUE
          return(private$factory$response(status = 422L))
        }
        mock$perform(url, headers, timeout)
      })
      testthat::expect_identical(GitHubCollector$new(fixture$config, fixture$store, http)$run(), "completed")
      testthat::expect_true(fixture$store$query("SELECT COUNT(*) n FROM problems WHERE code='http_failure'")$n > 0L)
      journal <- CollectionJournal$new(fixture$config)
      journal$record("github", fixture$store$run_id, "completed", fixture$config)
      mock <- MockHubTransport$new(private$factory)
      hf <- private$factory$http(fixture, "huggingface", mock$perform)
      fixture$config$osi$licenses <- Filter(function(x) x$id %in% c("MIT", "Apache-2.0"), fixture$config$osi$licenses)
      testthat::expect_identical(HuggingFaceCollector$new(fixture$config, fixture$store, hf)$run(), "completed")
      journal$record("huggingface", fixture$store$run_id, "completed", fixture$config)
      hf_client <- HuggingFaceClient$new(hf, fixture$config, fixture$store)
      testthat::expect_null(hf_client$repository("model", list()))
      malformed_detail <- private$factory$http(fixture, "huggingface", function(url, headers, timeout)
        private$factory$response(list(events = "not-a-list")))
      testthat::expect_null(HuggingFaceClient$new(malformed_detail, fixture$config, fixture$store)$discussion(
        list(type = "model", id = "org/demo"), 1L))
      testthat::expect_silent(AnalysisGate$new(fixture$config, fixture$store)$verify())
      result <- AnalysisExporter$new(fixture$config, fixture$store)$run()
      testthat::expect_true(file.exists(file.path(result$path, "coding.csv")))
      testthat::expect_equal(nrow(result$sample), 10L)
      testthat::expect_true(fixture$store$query("SELECT COUNT(*) n FROM problems WHERE code='http_failure' AND resolved=0")$n > 0L)
    }),
    collectors = function() testthat::test_that("coletores reais operam sobre respostas simuladas e deduplicam", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      mock <- MockHubTransport$new(private$factory)
      gh <- private$factory$http(fixture, "github", mock$perform)
      testthat::expect_identical(GitHubCollector$new(fixture$config, fixture$store, gh)$run(), "completed")
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM artifacts WHERE kind='issue'")$n, 1L)
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM artifacts WHERE kind='comment'")$n, 2L)
      testthat::expect_false("CPRA" %in% fixture$store$query("SELECT label FROM evidences WHERE platform='github' AND kind='legal'")$label)
      fixture$config$osi$licenses <- Filter(function(x) x$id %in% c("MIT", "Apache-2.0"), fixture$config$osi$licenses)
      hf <- private$factory$http(fixture, "huggingface", mock$perform)
      testthat::expect_identical(HuggingFaceCollector$new(fixture$config, fixture$store, hf)$run(), "completed")
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM artifacts WHERE kind='discussion'")$n, 2L)
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM artifacts WHERE kind='event'")$n, 2L)
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM repositories WHERE platform='huggingface'")$n, 2L)
      testthat::expect_equal(sum(fixture$store$counts()$legal_discussions$n), 3L)
      testthat::expect_equal(nrow(PopulationBuilder$new(fixture$store)$build()), 10L)
      testthat::expect_false(any(grepl("api/spaces", mock$requests)))
      testthat::expect_false(any(grepl("commits", mock$requests)))
    }),
    collection_optimization = function() {
      testthat::test_that("GitHub descarta itens inelegíveis antes de consultar seus repositórios", {
        fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
        mock <- MockHubTransport$new(private$factory)
        requests <- character()
        transport <- function(url, headers, timeout) {
          requests <<- c(requests, url)
          response <- mock$perform(gsub("org/(bot|pull|late|open)", "org/demo", url), headers, timeout)
          if (!grepl("/search/issues?", url, fixed = TRUE)) return(response)
          data <- jsonlite::fromJSON(rawToChar(response$body), simplifyVector = FALSE)
          for (i in 2:4) data$items[[i]]$repository_url <- paste0("https://api.github.com/repos/org/", c("bot", "pull", "late")[[i - 1L]])
          open <- data$items[[1L]]; open$id <- 5L; open$state <- "open"
          open$repository_url <- "https://api.github.com/repos/org/open"
          data$items <- c(data$items, list(open)); data$total_count <- 5L
          private$factory$response(data)
        }
        http <- private$factory$http(fixture, "github", transport)
        testthat::expect_identical(GitHubCollector$new(fixture$config, fixture$store, http)$run(), "completed")
        testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM repositories")$n, 1L)
        testthat::expect_false(any(grepl("/repos/org/(bot|pull|late|open)", requests)))
        testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM artifacts WHERE kind='issue'")$n, 1L)
        searches <- utils::URLdecode(requests[grepl("/search/issues?", requests, fixed = TRUE)])
        testthat::expect_length(searches, 4L)
        testthat::expect_match(searches[[1L]], '("GDPR" OR "General Data Protection Regulation")', fixed = TRUE)
        testthat::expect_match(searches[[2L]], '("CCPA" OR "California Consumer Privacy Act")', fixed = TRUE)
        testthat::expect_match(searches[[3L]], '("CPRA" OR "California Privacy Rights Act")', fixed = TRUE)
        testthat::expect_match(searches[[4L]], '"Data Protection Act"', fixed = TRUE)
        testthat::expect_false(any(grepl("advanced_search=", searches, fixed = TRUE)))
        requests <- character(); fixture$store$clear_platform("github")
        GitHubCollector$new(fixture$config, fixture$store, http, pilot = TRUE)$run()
        testthat::expect_equal(sum(grepl("/search/issues?", requests, fixed = TRUE)), 7L)
      })
      testthat::test_that("HF aproveita metadados completos e mantém consulta de detalhe e card como alternativa", {
        fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
        fixture$store$start("huggingface")
        mock <- MockHubTransport$new(private$factory)
        http <- private$factory$http(fixture, "huggingface", mock$perform)
        client <- HuggingFaceClient$new(http, fixture$config, fixture$store)
        rich <- list(id = "org/demo", createdAt = "2021-01-01T00:00:00Z", private = FALSE,
          gated = FALSE, disabled = FALSE, cardData = list(license = "mit", library_name = "transformers"))
        repo <- client$repository("model", rich)
        testthat::expect_true(repo$available)
        testthat::expect_identical(unname(repo$license), "MIT")
        testthat::expect_identical(AIClassifier$new(fixture$config)$huggingface(repo$metadata, repo$card)$status, "eligible")
        testthat::expect_length(mock$requests, 0L)
        repo <- client$repository("dataset", list(id = "org/demo"))
        testthat::expect_true(repo$available)
        testthat::expect_identical(unname(repo$license), "MIT")
        testthat::expect_equal(sum(grepl("/api/datasets/org/demo$", mock$requests)), 1L)
        unresolved <- rich; unresolved$cardData <- list(license = "mit")
        repo <- client$repository("dataset", unresolved)
        testthat::expect_identical(AIClassifier$new(fixture$config)$huggingface(repo$metadata, repo$card)$status, "eligible")
        testthat::expect_equal(sum(grepl("/resolve/main/README.md$", mock$requests)), 1L)
        client$walk_discovery("model", "mit", function(item) FALSE)
        client$walk_discovery("dataset", "mit", function(item) FALSE)
        discovery <- mock$requests[grepl("?filter=", mock$requests, fixed = TRUE)]
        testthat::expect_length(discovery, 2L)
        testthat::expect_true(all(grepl("expand=createdAt", discovery, fixed = TRUE)))
        testthat::expect_true(all(grepl("expand=cardData", discovery, fixed = TRUE)))
        testthat::expect_false(any(grepl("full=true", discovery, fixed = TRUE)))
        testthat::expect_false(any(grepl("pipeline_tag=|filter=transformers|filter=task", discovery)))
        malformed <- rich; malformed$cardData <- "invalid"
        testthat::expect_silent(repo <- client$repository("model", malformed))
        testthat::expect_true(repo$available)
        testthat::expect_identical(AIClassifier$new(fixture$config)$huggingface(repo$metadata, repo$card)$status, "eligible")
        invalid <- private$factory$http(fixture, "huggingface", function(url, headers, timeout)
          private$factory$response(list(cardData = "invalid")))
        testthat::expect_silent(repo <- HuggingFaceClient$new(invalid, fixture$config, fixture$store)$repository("model", list(id = "org/invalid")))
        testthat::expect_false(repo$available)
        testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM problems WHERE code='invalid_repository_response'")$n, 1L)
      })
      testthat::test_that("buscas combinadas preservam os termos ao dividir intervalos e paginar com sobreposição", {
        fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
        fixture$config$settings$http$page_size <- 2L
        fixture$store$start("github")
        urls <- character(); ids <- integer()
        http <- private$factory$http(fixture, "github", function(url, headers, timeout) {
          urls <<- c(urls, utils::URLdecode(url))
          if (grepl("23:59:58Z..2026-09-22T23:59:59Z", utils::URLdecode(url), fixed = TRUE)) {
            return(private$factory$response(list(total_count = 1001L, incomplete_results = FALSE, items = list())))
          }
          second <- grepl("&page=2", url, fixed = TRUE)
          last <- grepl("created:2026-09-22T23:59:59Z", utils::URLdecode(url), fixed = TRUE)
          page_ids <- if (last) 4L else if (second) c(2L, 3L) else c(1L, 2L)
          link <- if (!last && !second) list(link = paste0("<", sub("&page=1", "&page=2", url, fixed = TRUE), '>; rel="next"')) else list()
          private$factory$response(list(total_count = if (last) 1L else 3L, incomplete_results = FALSE,
            items = lapply(page_ids, function(id) list(id = id))), headers = link)
        })
        received <- GitHubSearch$new(http, fixture$config, fixture$store)$walk(
          c("GDPR", "General Data Protection Regulation"), "2026-09-22T23:59:58Z", function(item) ids <<- c(ids, item$id))
        testthat::expect_identical(ids, 1:4)
        testthat::expect_equal(received, 4L)
        testthat::expect_length(urls, 4L)
        testthat::expect_true(all(grepl('(\"GDPR\" OR \"General Data Protection Regulation\")', urls, fixed = TRUE)))
        testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM problems")$n, 0L)
      })
      testthat::test_that("OR saturado em um segundo recorre aos termos separados sem perder resultados nem duplicar", {
        fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
        fixture$store$start("github")
        urls <- character()
        http <- private$factory$http(fixture, "github", function(url, headers, timeout) {
          query <- utils::URLdecode(url); urls <<- c(urls, query)
          combined <- grepl(" OR ", query, fixed = TRUE)
          parent <- grepl("23:59:58Z..2026-09-22T23:59:59Z", query, fixed = TRUE)
          last <- grepl("created:2026-09-22T23:59:59Z", query, fixed = TRUE)
          if (combined && !last) return(private$factory$response(list(total_count = if (parent) 1101L else 1100L,
            incomplete_results = FALSE, items = list())))
          page <- as.integer(sub(".*&page=", "", url))
          pool <- if (last) { if (combined) 1101L else integer() } else
            if (grepl('"General Data Protection Regulation"', query, fixed = TRUE)) 501:1100 else 1:600
          first <- (page - 1L) * 100L + 1L
          ids <- head(pool[seq_along(pool) >= first], 100L)
          link <- if (page * 100L < length(pool)) list(link = paste0('<', sub("&page=[0-9]+$", paste0("&page=", page + 1L), url), '>; rel="next"')) else list()
          private$factory$response(list(total_count = length(pool), incomplete_results = FALSE,
            items = lapply(ids, function(id) list(id = id))), headers = link)
        })
        search <- GitHubSearch$new(http, fixture$config, fixture$store)
        for (limit in c(Inf, 1000L)) {
          ids <- integer(); urls <- character()
          received <- search$walk(c("GDPR", "General Data Protection Regulation"),
            "2026-09-22T23:59:58Z", function(item) ids <<- c(ids, item$id), limit)
          testthat::expect_equal(received, min(1101L, limit))
          testthat::expect_identical(sort(ids), seq_len(min(1101L, limit)))
          testthat::expect_equal(anyDuplicated(ids), 0L)
          last_urls <- urls[grepl("created:2026-09-22T23:59:59Z", urls, fixed = TRUE)]
          if (is.infinite(limit)) testthat::expect_true(length(last_urls) == 1L && grepl(" OR ", last_urls, fixed = TRUE))
        }
        testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM problems")$n, 0L)
      })
    },
    collection_recovery = function() testthat::test_that("retomada reaproveita respostas válidas sem reutilizar falhas, buscas ou outro protocolo", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      manager <- DatabaseManager$new(fixture$config, fresh = TRUE)
      source <- AuditStore$new(manager$staging, fixture$config)
      source$start("github")
      urls <- paste0("https://api.github.com/repos/org/", c("valid", "invalid", "failed", "tampered", "missing"))
      for (i in seq_along(urls)) source$response(urls[[i]], private$factory$response(list(name = paste0("repo", i))), 1L)
      source$problem("invalid_repository_response", urls[[2L]], "Metadados inválidos")
      source$response(urls[[3L]], private$factory$response(status = 503L), 2L)
      raw <- source$query("SELECT url,path FROM responses")
      writeBin(charToRaw("changed"), fixture$config$path(raw$path[match(urls[[4L]], raw$url)]))
      unlink(fixture$config$path(raw$path[match(urls[[5L]], raw$url)]))
      refreshed <- c("https://api.github.com/search/issues?q=GDPR",
        "https://api.github.com/repos/org/demo/issues/1/comments?per_page=100")
      for (url in refreshed) source$response(url, private$factory$response(list(name = "old")), 1L)
      source$finish("failed"); source$close()
      snapshot <- manager$preserve_failure()
      original_hash <- digest::digest(file = snapshot, algo = "sha256", serialize = FALSE)
      recovered <- AuditStore$new(DatabaseManager$new(fixture$config, fresh = TRUE)$staging, fixture$config, recover = TRUE)
      on.exit(recovered$close(), add = TRUE)
      recovered$start("github")
      calls <- character()
      http <- private$factory$http(list(config = fixture$config, store = recovered), "github", function(url, headers, timeout) {
        calls <<- c(calls, url)
        private$factory$response(list(name = "fresh"))
      })
      testthat::expect_identical(http$get(urls[[1L]])$data$name, "repo1")
      testthat::expect_length(calls, 0L)
      for (url in urls[-1L]) testthat::expect_identical(http$get(url)$data$name, "fresh")
      for (url in refreshed) testthat::expect_identical(http$get(url, if (grepl("/search/", url)) "search" else "api")$data$name, "fresh")
      testthat::expect_length(calls, 6L)
      testthat::expect_equal(recovered$query("SELECT COUNT(*) n FROM responses WHERE attempt=0")$n, 1L)
      testthat::expect_equal(recovered$query("SELECT COUNT(*) n FROM attempts")$n, 6L)
      testthat::expect_identical(digest::digest(file = snapshot, algo = "sha256", serialize = FALSE), original_hash)
      recovered$start("huggingface")
      testthat::expect_null(recovered$replay(urls[[1L]]))
      recovered$start("github", pilot = TRUE)
      testthat::expect_null(recovered$replay(urls[[1L]]))
      changed <- ProjectConfig$new(private$config$root)
      changed$root <- fixture$config$root; changed$fingerprint <- "another-protocol"
      different <- AuditStore$new(file.path(changed$root, "different.sqlite"), changed, recover = TRUE)
      on.exit(different$close(), add = TRUE); different$start("github")
      testthat::expect_null(different$replay(urls[[1L]]))
      official <- AuditStore$new(fixture$config$path(fixture$config$settings$paths$database), fixture$config)
      official$start("github"); official$finish(); official$close()
      # O snapshot antigo deve anteceder o banco de uma coleta concluída.
      Sys.setFileTime(snapshot, Sys.time() - 60)
      newer <- AuditStore$new(file.path(fixture$config$root, "newer.sqlite"), fixture$config, recover = TRUE)
      on.exit(newer$close(), add = TRUE); newer$start("github")
      testthat::expect_null(newer$replay(urls[[1L]]))
    }),
    hf_recovery = function() testthat::test_that("HF retoma metadados e cards e consulta Discussions novamente", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      manager <- DatabaseManager$new(fixture$config, fresh = TRUE)
      source <- AuditStore$new(manager$staging, fixture$config)
      source$start("huggingface")
      api <- "https://huggingface.co/api/datasets/org/demo"
      source$response(api, private$factory$response(list(id = "org/demo", createdAt = "2021-01-01T00:00:00Z",
        private = FALSE, gated = FALSE, disabled = FALSE)), 1L)
      source$response("https://huggingface.co/datasets/org/demo/resolve/main/README.md",
        private$factory$response(text = "---\nlicense: mit\ntask_categories: [text-classification]\n---\nCard"), 1L)
      discussion <- paste0(api, "/discussions/1")
      source$response(discussion, private$factory$response(list(events = list(), title = "old")), 1L)
      source$close(); manager$preserve_failure()
      store <- AuditStore$new(DatabaseManager$new(fixture$config, fresh = TRUE)$staging, fixture$config, recover = TRUE)
      on.exit(store$close(), add = TRUE); store$start("huggingface")
      calls <- character()
      http <- private$factory$http(list(config = fixture$config, store = store), "huggingface", function(url, headers, timeout) {
        calls <<- c(calls, url)
        private$factory$response(list(events = list(), title = "fresh"))
      })
      client <- HuggingFaceClient$new(http, fixture$config, store)
      repo <- client$repository("dataset", list(id = "org/demo"))
      testthat::expect_length(calls, 0L)
      testthat::expect_identical(unname(repo$license), "MIT")
      testthat::expect_identical(AIClassifier$new(fixture$config)$huggingface(repo$metadata, repo$card)$status, "eligible")
      testthat::expect_identical(client$discussion(repo, 1L)$title, "fresh")
      testthat::expect_identical(calls, discussion)
      testthat::expect_equal(store$query("SELECT COUNT(*) n FROM responses WHERE attempt=0")$n, 2L)
    }),
    github_cutoff = function() testthat::test_that("menções posteriores ao corte são exclusões, mantendo falhas de coleta distintas", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      mock <- MockHubTransport$new(private$factory)
      late <- list(id = 10L, created_at = "2026-09-23T00:00:00Z", body = "xgDpRy")
      boundary <- list(id = 11L, created_at = "2026-09-22T23:59:59.999Z", body = "GDPR")
      unknown <- list(id = 12L, body = "GDPR")
      cases <- list(
        list(comments = list(late), expected = 1L, status = "completed", population = 0L, code = "search_hit_after_cutoff", pending = 0L),
        list(comments = list(boundary), expected = 1L, status = "completed", population = 1L, code = character(), pending = 0L),
        list(comments = list(list(id = 13L, created_at = "2022-01-01T00:00:00Z", body = "consent")), expected = 1L,
          status = "completed", population = 0L, code = "unconfirmed_search_hit", pending = 1L),
        list(comments = list(unknown), expected = 1L, status = "completed", population = 0L, code = "unconfirmed_search_hit", pending = 1L),
        list(comments = list(late, unknown), expected = 2L, status = "completed", population = 0L, code = "unconfirmed_search_hit", pending = 1L),
        list(comments = list(late), expected = 2L, status = "completed", population = 0L, code = "comments_incomplete", pending = 1L),
        list(comments = list(), expected = 0L, status = "completed", population = 0L, code = "unconfirmed_search_hit", pending = 1L))
      for (case in cases) {
        fixture$store$clear_platform("github")
        transport <- function(url, headers, timeout) {
          if (grepl("/search/issues?", url, fixed = TRUE)) return(private$factory$response(list(
            total_count = 1L, incomplete_results = FALSE, items = list(list(id = 101L, number = 1L,
              title = "Data handling", body = "No legal term here", state = "closed", created_at = "2022-01-01T00:00:00Z",
              repository_url = "https://api.github.com/repos/org/demo", comments_url = "https://api.github.com/repos/org/demo/issues/1/comments",
              html_url = "https://github.com/org/demo/issues/1", comments = case$expected, user = list(type = "User", login = "person"))))))
          if (grepl("/comments?", url, fixed = TRUE)) return(private$factory$response(case$comments))
          mock$perform(url, headers, timeout)
        }
        http <- private$factory$http(fixture, "github", transport)
        testthat::expect_identical(GitHubCollector$new(fixture$config, fixture$store, http)$run(), case$status)
        testthat::expect_equal(nrow(PopulationBuilder$new(fixture$store)$build()), case$population)
        problems <- fixture$store$query("SELECT code,resolved FROM problems WHERE run_id=?", list(fixture$store$run_id))
        testthat::expect_identical(problems$code, case$code)
        testthat::expect_equal(sum(problems$resolved == 0L), case$pending)
        testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM artifacts WHERE kind='comment' AND created>'2026-09-22T23:59:59.999Z'")$n, 0L)
      }
    }),
    hf_filters = function() testthat::test_that("HF exige Discussions fechadas sem bots na listagem e nos detalhes", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$config$osi$licenses <- Filter(function(x) x$id == "MIT", fixture$config$osi$licenses)
      fixture$config$settings$eligibility$hf_bot_accounts <- list("parquet-converter")
      mock <- MockHubTransport$new(private$factory)
      human <- list(name = "person", type = "user")
      items <- lapply(1:9, function(number) list(num = number, createdAt = "2022-01-01T00:00:00Z",
        isPullRequest = FALSE, status = "closed", author = human))
      items[[2L]]$status <- "open"
      items[[3L]]$author$name <- "parquet-converter"
      items[[4L]]$author$type <- "bot"
      items[[5L]]$author$name <- "build-bot"
      items[[8L]]$status <- NULL
      items[[9L]]$isPullRequest <- TRUE
      requests <- character()
      transport <- function(url, headers, timeout) {
        requests <<- c(requests, url)
        if (grepl("/discussions?p=", url, fixed = TRUE)) return(private$factory$response(list(start = 0L, count = 9L, discussions = items)))
        if (grepl("/discussions/", url, fixed = TRUE)) {
          number <- as.integer(sub(".*/discussions/", "", url))
          detail <- items[[number]]
          detail$title <- "GDPR"
          detail$events <- list()
          if (number == 6L) detail$status <- "open"
          if (number == 7L) detail$author$name <- "parquet-converter"
          return(private$factory$response(detail))
        }
        mock$perform(url, headers, timeout)
      }
      http <- private$factory$http(fixture, "huggingface", transport)
      testthat::expect_identical(HuggingFaceCollector$new(fixture$config, fixture$store, http)$run(), "completed")
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM artifacts WHERE kind='discussion'")$n, 2L)
      testthat::expect_equal(nrow(PopulationBuilder$new(fixture$store)$build()), 2L)
      requested <- sort(unique(as.integer(sub(".*/discussions/", "", requests[grepl("/discussions/", requests, fixed = TRUE)]))))
      testthat::expect_identical(requested, c(1L, 6L, 7L))
      policy <- EligibilityPolicy$new(fixture$config)
      testthat::expect_false(policy$bot(list(login = "parquet-converter", type = "User")))
      testthat::expect_true(policy$bot(list(name = "PARQUET-CONVERTER", type = "user"), "huggingface"))
      testthat::expect_false(policy$bot(list(name = "parquet-converter-human", type = "user"), "huggingface"))
      testthat::expect_false(policy$bot(list(name = "robotics", type = "user"), "huggingface"))
    }),
    storage = function() testthat::test_that("bancos oficiais são preservados até promoção explícita", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      target <- fixture$config$path(fixture$config$settings$paths$database)
      dir.create(dirname(target), recursive = TRUE)
      writeLines("old", target)
      manager <- DatabaseManager$new(fixture$config)
      writeLines("new", manager$staging)
      testthat::expect_identical(readLines(target), "old")
      manager$promote()
      testthat::expect_identical(readLines(target), "new")
      testthat::expect_identical(readLines(list.files(fixture$config$path("inputs/data/archive"), full.names = TRUE)), "old")
      pilot <- DatabaseManager$new(fixture$config, pilot = TRUE, fresh = TRUE)
      testthat::expect_false(identical(pilot$target, target))
      lock <- RunLock$new(fixture$config$root)
      testthat::expect_true(file.exists(fixture$config$path(".run-lock/pid")))
      testthat::expect_error(RunLock$new(fixture$config$root), "Outra execução")
      lock$release()
    }),
    pilot_retention = function() testthat::test_that("piloto substitui somente seus dados e limpa também tentativas falhas", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      config <- fixture$config
      config$settings$paths <- list(database = "inputs/data/research.sqlite", pilot_database = "inputs/data/pilot/pilot.sqlite",
        raw = "inputs/raw", archive = "inputs/data/archive", analysis = "inputs/final/collection")
      official <- c("inputs/data/research.sqlite", "inputs/data/archive/previous.sqlite",
        "inputs/raw/official/response.body", "inputs/final/coding-reviewed.csv")
      pilot_files <- c("inputs/data/pilot/pilot.sqlite", "inputs/data/pilot/summary.json",
        "inputs/data/pilot/.staging-old-failed.sqlite", "inputs/raw/pilot/old/response.body")
      for (path in c(official, pilot_files)) {
        dir.create(dirname(config$path(path)), recursive = TRUE, showWarnings = FALSE)
        writeLines(path, config$path(path))
      }
      official_hashes <- vapply(official, function(path) digest::digest(file = config$path(path), algo = "sha256", serialize = FALSE), "")
      pilot_data <- config$path("inputs/data/pilot")
      pilot_raw <- config$path("inputs/raw/pilot")
      manager <- DatabaseManager$new(config, pilot = TRUE, fresh = TRUE)
      testthat::expect_length(list.files(pilot_data, all.files = TRUE, no.. = TRUE), 0L)
      testthat::expect_length(list.files(pilot_raw, all.files = TRUE, no.. = TRUE), 0L)
      store <- AuditStore$new(manager$staging, config)
      on.exit(store$close(), add = TRUE)
      store$start("github", pilot = TRUE)
      response <- private$factory$response(list(current = TRUE))
      store$response("https://api.github.com/test", response, 1L)
      record <- store$query("SELECT path,sha256 FROM responses")
      testthat::expect_identical(record$path, file.path("inputs/raw/pilot", store$run_id, paste0(record$sha256, ".body")))
      testthat::expect_identical(readBin(config$path(record$path), "raw", n = length(response$body)), response$body)
      store$finish(); store$close(); manager$promote()
      writeLines("current", file.path(pilot_data, "summary.json"))
      testthat::expect_identical(list.files(pilot_data), c("pilot.sqlite", "summary.json"))
      next_pilot <- DatabaseManager$new(config, pilot = TRUE, fresh = TRUE)
      testthat::expect_length(list.files(pilot_data, all.files = TRUE, no.. = TRUE), 0L)
      testthat::expect_length(list.files(pilot_raw, all.files = TRUE, no.. = TRUE), 0L)
      testthat::expect_false(file.exists(config$path(record$path)))
      writeLines("failed", next_pilot$staging)
      failed <- next_pilot$preserve_failure()
      testthat::expect_true(file.exists(failed))
      latest <- DatabaseManager$new(config, pilot = TRUE, fresh = TRUE)
      testthat::expect_false(file.exists(failed))
      writeLines("latest", latest$staging); latest$promote()
      testthat::expect_identical(list.files(pilot_data, all.files = TRUE, no.. = TRUE), "pilot.sqlite")
      testthat::expect_identical(vapply(official, function(path) digest::digest(file = config$path(path), algo = "sha256", serialize = FALSE), ""), official_hashes)
      testthat::expect_identical(list.files(config$path("inputs/data/archive")), "previous.sqlite")
      config$settings$paths$pilot_database <- config$settings$paths$database
      testthat::expect_error(DatabaseManager$new(config, pilot = TRUE), "pilot")
      config$settings$paths$pilot_database <- "inputs/data/pilot/pilot.sqlite"
      config$settings$paths$database <- "inputs/data/pilot/official.sqlite"
      testthat::expect_error(DatabaseManager$new(config, pilot = TRUE), "oficiais")
      testthat::expect_identical(readLines(latest$target), "latest")
      config$settings$paths$database <- "inputs/data/research.sqlite"
      outside <- tempfile("privacy-outside-")
      dir.create(file.path(outside, "pilot"), recursive = TRUE)
      on.exit(unlink(outside, recursive = TRUE), add = TRUE)
      protected <- file.path(outside, "pilot", "keep.sqlite")
      writeLines("protected", protected)
      config$settings$paths$pilot_database <- file.path(outside, "pilot", "pilot.sqlite")
      testthat::expect_error(DatabaseManager$new(config, pilot = TRUE), "dentro do projeto")
      link <- config$path("links/pilot")
      dir.create(dirname(link))
      testthat::expect_true(file.symlink(file.path(outside, "pilot"), link))
      config$settings$paths$pilot_database <- "links/pilot/pilot.sqlite"
      testthat::expect_error(DatabaseManager$new(config, pilot = TRUE), "dentro do projeto")
      testthat::expect_identical(readLines(protected), "protected")
      testthat::expect_identical(readLines(latest$target), "latest")
    }),
    pilot_limits = function() testthat::test_that("tetos do piloto limitam operações e preservam critérios", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$config$osi$licenses <- Filter(function(x) x$id == "MIT", fixture$config$osi$licenses)
      limits <- fixture$config$settings$pilot
      limits$github_repositories <- 2L; limits$github_issues <- 1L; limits$github_comments <- 1L
      limits$hf_discovered_per_type <- 2L; limits$hf_eligible_per_type <- 1L; limits$hf_discussions_per_repo <- 2L
      fixture$config$settings$pilot <- limits
      mock <- MockHubTransport$new(private$factory)
      transport <- function(url, headers, timeout) {
        normalized <- gsub("org/r[1234]", "org/demo", url)
        response <- mock$perform(normalized, headers, timeout)
        if (grepl("/search/issues?", url, fixed = TRUE)) {
          data <- jsonlite::fromJSON(rawToChar(response$body), simplifyVector = FALSE)
          for (index in seq_along(data$items)) {
            data$items[[index]]$user$type <- "User"
            data$items[[index]]$pull_request <- NULL
            data$items[[index]]$created_at <- "2022-01-01T00:00:00Z"
            data$items[[index]]$repository_url <- paste0("https://api.github.com/repos/org/r", index)
          }
          return(private$factory$response(data))
        }
        if (grepl("?filter=", url, fixed = TRUE)) return(private$factory$response(lapply(1:3, function(index) list(id = paste0("org/r", index)))))
        if (grepl("/discussions?p=", url, fixed = TRUE)) {
          data <- jsonlite::fromJSON(rawToChar(response$body), simplifyVector = FALSE)
          data$discussions[[3L]]$createdAt <- "2022-01-01T00:00:00Z"
          return(private$factory$response(data))
        }
        response
      }
      gh <- private$factory$http(fixture, "github", transport)
      testthat::expect_identical(GitHubCollector$new(fixture$config, fixture$store, gh, TRUE)$run(), "completed")
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM repositories WHERE platform='github'")$n, 2L)
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM artifacts WHERE kind='issue'")$n, 1L)
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM artifacts WHERE kind='comment'")$n, 1L)
      hf <- private$factory$http(fixture, "huggingface", transport)
      testthat::expect_identical(HuggingFaceCollector$new(fixture$config, fixture$store, hf, TRUE)$run(), "completed")
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM repositories WHERE platform='huggingface'")$n, 4L)
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM artifacts WHERE kind='discussion'")$n, 2L)
      testthat::expect_false(any(grepl("/discussions/3", mock$requests, fixed = TRUE)))
      testthat::expect_true(all(fixture$store$query("SELECT pilot FROM runs")$pilot == 1L))
      testthat::expect_true("pilot_comment_limit" %in% fixture$store$query("SELECT code FROM problems WHERE resolved=1")$code)
    }),
    unavailability = function() testthat::test_that("Discussions desativadas ficam separadas de falhas HTTP", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("huggingface")
      disabled <- private$factory$http(fixture, "huggingface", function(url, headers, timeout)
        private$factory$response(list(error = "Discussions are disabled for this repo"), 403L))
      client <- HuggingFaceClient$new(disabled, fixture$config, fixture$store)
      testthat::expect_length(client$discussions(list(type = "model", id = "org/demo")), 0L)
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM unavailable")$n, 1L)
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM problems WHERE resolved=0")$n, 0L)
      testthat::expect_identical(fixture$store$finish(), "completed")
      malformed <- private$factory$http(fixture, "huggingface", function(url, headers, timeout)
        private$factory$response(text = "not json", headers = list(`content-type` = "application/json")))
      testthat::expect_null(malformed$get("https://huggingface.co/api/test"))
      testthat::expect_true("invalid_json" %in% fixture$store$query("SELECT code FROM problems")$code)
    }),
    sampling = function() testthat::test_that("Cochran, estratos e sorteio são reprodutíveis", {
      sampler <- StratifiedSampler$new(private$config)
      testthat::expect_equal(sampler$size(0), 0L)
      testthat::expect_equal(sampler$size(100), 88L)
      testthat::expect_equal(sampler$size(10000), 623L)
      population <- data.frame(unit_key = sprintf("u%04d", 1:1000), repo_key = "repo",
        platform = "github", repo_type = "repository", law = "GDPR", url = "url", created = "2022-01-01")
      population <- rbind(population, transform(population[1:10, ], law = "CCPA"))
      set.seed(123); old <- .Random.seed
      first <- sampler$draw(population)
      testthat::expect_identical(.Random.seed, old)
      second <- sampler$draw(population[nrow(population):1, ])
      testthat::expect_equal(first, second)
      testthat::expect_equal(first$strata$seed, c(20260921, 20260922))
      testthat::expect_equal(anyDuplicated(first$sample[c("unit_key", "law")]), 0L)
    }),
    coding = function() testthat::test_that("codificações e kappa tratam duplicação e respostas ausentes", {
      rows <- data.frame(unit_key = rep(c("a", "b", "c", "d"), 2), reviewer = rep(c("r1", "r2"), each = 4),
        codebook_version = private$config$taxonomy$version, relevance = c("0", "0", "1", "1", "0", "1", "1", "1"), categories = "")
      validator <- CodingValidator$new(private$config, c("a", "b", "c", "d"))
      testthat::expect_silent(validator$validate(rows))
      testthat::expect_error(validator$validate(rbind(rows, rows[1, ])), "duplicada")
      invalid <- rows; invalid$relevance[1] <- "2"
      testthat::expect_error(validator$validate(invalid), "Relevância")
      invalid <- rows; invalid$categories[1] <- "C01;C01"
      testthat::expect_error(validator$validate(invalid), "repetida")
      invalid$categories[1] <- "C99"
      testthat::expect_error(validator$validate(invalid), "taxonomia")
      calculator <- KappaCalculator$new()
      testthat::expect_equal(calculator$compute(rows, c("r1", "r2"))$kappa, 0.5)
      testthat::expect_error(calculator$compute(rows, c("r1", "r1")), "distintos")
      rows$relevance[1:4] <- ""
      testthat::expect_true(is.na(calculator$compute(rows, c("r1", "r2"))$kappa))
      rows$relevance <- "1"
      testthat::expect_identical(calculator$compute(rows, c("r1", "r2"))$reason, "expected_agreement_one")
      rows$relevance[1] <- NA
      testthat::expect_equal(calculator$compute(rows, c("r1", "r2"))$pairs, 3L)
    }),
    analysis = function() testthat::test_that("análise rejeita última tentativa falha e evidências alteradas", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      gate <- AnalysisGate$new(fixture$config, fixture$store)
      testthat::expect_error(gate$verify(), "ausente")
      journal <- CollectionJournal$new(fixture$config)
      for (platform in c("github", "huggingface")) {
        fixture$store$start(platform)
        if (platform == "github") fixture$store$problem("search_empty_second", "GDPR", "Intervalo sem itens verificáveis")
        fixture$store$response(paste0("https://example/", platform), private$factory$response(), 1L)
        status <- fixture$store$finish()
        journal$record(platform, fixture$store$run_id, status, fixture$config)
      }
      testthat::expect_silent(gate$verify())
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM problems WHERE resolved=0")$n, 1L)
      fixture$store$problem("http_failure", "https://api.github.com", "HTTP 503")
      testthat::expect_silent(gate$verify())
      exported <- AnalysisExporter$new(fixture$config, fixture$store)$run()
      testthat::expect_true(file.exists(file.path(exported$path, "coding.csv")))
      testthat::expect_equal(nrow(exported$sample), 0L)
      reviewed <- fixture$config$path("inputs/final/coding-reviewed.csv")
      dir.create(dirname(reviewed), recursive = TRUE, showWarnings = FALSE)
      writeLines("reviewed", reviewed)
      AnalysisExporter$new(fixture$config, fixture$store)$run()
      testthat::expect_identical(readLines(reviewed), "reviewed")
      previous <- list.dirs(fixture$config$path("inputs/final/archive"), recursive = FALSE, full.names = TRUE)
      testthat::expect_length(previous, 1L)
      testthat::expect_true(file.exists(file.path(previous, "coding.csv")))
      journal$record("github", "new-failed", "failed", fixture$config)
      testthat::expect_error(gate$verify(), "última tentativa")
      run <- fixture$store$query("SELECT run_id FROM runs WHERE platform='github'")$run_id
      journal$record("github", run, "completed", fixture$config)
      raw_path <- fixture$config$path(fixture$store$query("SELECT path FROM responses LIMIT 1")$path)
      writeLines("tampered", raw_path)
      testthat::expect_error(gate$verify(), "alterada")
    }),
    pipeline = function() testthat::test_that("coleta, amostra e planilhas funcionam juntas com dados simulados", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      mock <- MockHubTransport$new(private$factory)
      journal <- CollectionJournal$new(fixture$config)
      gh <- private$factory$http(fixture, "github", mock$perform)
      GitHubCollector$new(fixture$config, fixture$store, gh)$run()
      fixture$store$problem("search_empty_second", "GDPR", "Intervalo sem itens verificáveis")
      github_status <- fixture$store$finish()
      journal$record("github", fixture$store$run_id, github_status, fixture$config)
      fixture$config$osi$licenses <- Filter(function(x) x$id %in% c("MIT", "Apache-2.0"), fixture$config$osi$licenses)
      hf <- private$factory$http(fixture, "huggingface", mock$perform)
      HuggingFaceCollector$new(fixture$config, fixture$store, hf)$run()
      journal$record("huggingface", fixture$store$run_id, "completed", fixture$config)
      testthat::expect_silent(AnalysisGate$new(fixture$config, fixture$store)$verify())
      result <- AnalysisExporter$new(fixture$config, fixture$store)$run()
      coding <- utils::read.csv(file.path(result$path, "coding.csv"), colClasses = "character")
      testthat::expect_equal(nrow(coding), 6L)
      testthat::expect_equal(nrow(result$sample), 10L)
      testthat::expect_equal(fixture$store$query("SELECT COUNT(*) n FROM problems WHERE code='search_empty_second' AND resolved=0")$n, 1L)
      testthat::expect_equal(length(unique(coding$unit_key)), 3L)
      testthat::expect_equal(anyDuplicated(coding[c("unit_key", "reviewer", "codebook_version")]), 0L)
      testthat::expect_true(all(coding$relevance == ""))
      testthat::expect_true(all(coding$categories == ""))
      testthat::expect_true(is.na(result$kappa$kappa))
      testthat::expect_silent(CodingValidator$new(fixture$config, unique(coding$unit_key))$validate(coding))
    }),
    application = function() testthat::test_that("CLI preserva a outra plataforma, suporta ambas as ordens e falhas", {
      root <- tempfile("privacy-app-"); dir.create(root)
      on.exit(unlink(root, recursive = TRUE), add = TRUE)
      file.copy(private$config$path("config"), root, recursive = TRUE)
      osi <- private$config$osi
      osi$licenses <- Filter(function(x) x$id %in% c("MIT", "Apache-2.0"), osi$licenses)
      writeLines(ProtocolTools$new()$json(osi), file.path(root, "config/osi-licenses.json"))
      mock <- MockHubTransport$new(private$factory)
      failure <- FALSE; inject_gap <- FALSE; gap_recorded <- FALSE
      factory <- function(platform, config, store) {
        now <- 0
        transport <- if (failure && platform == "github") function(url, headers, timeout) private$factory$response(status = 503L) else
          if (inject_gap && platform == "github") function(url, headers, timeout) {
            if (!gap_recorded && grepl("/search/issues?", url, fixed = TRUE)) {
              store$problem("search_empty_second", "GDPR", "Intervalo sem itens verificáveis")
              gap_recorded <<- TRUE
            }
            mock$perform(url, headers, timeout)
          } else mock$perform
        HttpClient$new(platform, config, store, transport, function() now, function(seconds) now <<- now + seconds)
      }
      app <- ProjectApplication$new(root, private$environment, factory)
      testthat::expect_error(app$run(c("--mode", "github", "--mode", "huggingface")), "apenas uma")
      testthat::expect_error(app$run(c("--github", "--huggingface")), "apenas uma")
      testthat::expect_error(app$run(c("--pilot", "--mode", "github")), "apenas uma")
      testthat::expect_error(app$run(c("--mode", "unknown")), "Modalidade inválida")
      testthat::expect_error(app$run(c("--mode", "full")), "Modalidade inválida")
      testthat::expect_error(app$run("--no-site"), "Opção inválida")
      testthat::expect_error(app$run("--analyze"), "ausente")
      app$run("--huggingface")
      testthat::expect_true(file.exists(file.path(root, "outputs/metadata/site-failure.txt")))
      app$run("--github")
      config <- ProjectConfig$new(root)
      path <- config$path(config$settings$paths$database)
      store <- AuditStore$new(path, config)
      testthat::expect_equal(sum(store$counts()$legal_discussions$n), 3L)
      store$close()
      unlink(file.path(root, "outputs/metadata/site-failure.txt"))
      app$run("--analyze")
      testthat::expect_true(file.exists(file.path(root, "outputs/metadata/site-failure.txt")))
      hash <- digest::digest(file = path, algo = "sha256", serialize = FALSE)
      failure <- TRUE
      partial <- capture.output(app$run("--github"))
      testthat::expect_true(any(grepl("diagnósticos registrados", partial)))
      testthat::expect_false(identical(digest::digest(file = path, algo = "sha256", serialize = FALSE), hash))
      invisible(capture.output(app$run("--analyze")))
      testthat::expect_false(dir.exists(file.path(root, ".run-lock")))
      failure <- FALSE
      app$run("--github")
      app$run("--huggingface")
      inject_gap <- TRUE
      output <- capture.output(app$run(c("--mode", "run")))
      inject_gap <- FALSE
      output_text <- paste(output, collapse = "\n")
      testthat::expect_true(gap_recorded)
      testthat::expect_match(output_text, "1 intervalo sem resultado verificável; desconsiderados na análise")
      testthat::expect_false(grepl("paginação divergente|página vazia persistente|intervalo de um segundo", output_text))
      gap_store <- AuditStore$new(path, config)
      gap_run <- gap_store$query("SELECT run_id,status FROM runs WHERE platform='github' AND pilot=0 ORDER BY rowid DESC LIMIT 1")
      testthat::expect_identical(gap_run$status, "completed")
      testthat::expect_equal(gap_store$query("SELECT COUNT(*) n FROM problems WHERE run_id=? AND code='search_empty_second' AND resolved=0", list(gap_run$run_id))$n, 1L)
      testthat::expect_silent(AnalysisGate$new(config, gap_store)$verify())
      gap_store$close()
      testthat::expect_true(file.exists(config$path("inputs/final/collection/coding.csv")))
      testthat::expect_equal(nrow(utils::read.csv(config$path("inputs/final/collection/sample.csv"))), 10L)
      hash <- digest::digest(file = path, algo = "sha256", serialize = FALSE)
      failure <- TRUE
      partial <- capture.output(app$run("--run"))
      testthat::expect_true(any(grepl("diagnósticos registrados", partial)))
      testthat::expect_false(identical(digest::digest(file = path, algo = "sha256", serialize = FALSE), hash))
      testthat::expect_gt(nrow(utils::read.csv(config$path("inputs/final/collection/sample.csv"))), 0L)
      testthat::expect_false(dir.exists(file.path(root, ".run-lock")))
      hash <- digest::digest(file = path, algo = "sha256", serialize = FALSE)
      failure <- FALSE
      unlink(file.path(root, "outputs/metadata/site-failure.txt"))
      output <- capture.output(app$run("--pilot"))
      testthat::expect_match(paste(output, collapse = "\n"), "\\[1/2\\] Coleta GitHub")
      testthat::expect_match(paste(output, collapse = "\n"), "Busca 1/7: GDPR")
      testthat::expect_false(file.exists(file.path(root, "outputs/metadata/site-failure.txt")))
      testthat::expect_true(file.exists(config$path(config$settings$paths$pilot_database)))
      testthat::expect_true(file.exists(config$path("inputs/data/pilot/summary.json")))
      testthat::expect_identical(sort(jsonlite::fromJSON(config$path("inputs/data/pilot/summary.json"))$runs$platform), c("github", "huggingface"))
      testthat::expect_true(file.exists(config$path("inputs/data/latest-collections.json")))
      testthat::expect_identical(list.dirs(file.path(root, "outputs"), recursive = FALSE, full.names = FALSE), c("metadata", "reports", "tables"))
      testthat::expect_identical(digest::digest(file = path, algo = "sha256", serialize = FALSE), hash)
    }),
    progress = function() {
      private$progress_times()
      private$progress_terminal()
      private$progress_waits()
      private$progress_application()
    },
    progress_times = function() testthat::test_that("resumos respeitam cinco minutos e total continua entre buscas e etapas", {
      now <- 100; output <- character(); reads <- 0L
      progress <- ConsoleProgress$new(clock = function() now, terminal = FALSE,
        write = function(text) output <<- c(output, text))
      progress$begin("Execução completa", 4L, started = 0)
      progress$stage("Coleta GitHub", function() { reads <<- reads + 1L; "avaliados: 12" })
      progress$scope("Busca 1/7: GDPR", "GDPR")
      progress$activity("Coletando comentários")
      baseline <- length(output)
      now <- 399
      testthat::expect_true(progress$tick())
      testthat::expect_length(output, baseline)
      now <- 400; progress$tick()
      testthat::expect_match(tail(output, 1L), "Busca: 00:05:00.*Total: 00:06:40")
      testthat::expect_match(tail(output, 1L), "avaliados: 12")
      testthat::expect_equal(reads, 1L)
      now <- 700; progress$tick()
      testthat::expect_match(tail(output, 1L), "Busca: 00:10:00.*Total: 00:11:40")
      now <- 750; progress$scope("Busca 2/7: CCPA", "CCPA")
      now <- 1000; progress$tick()
      testthat::expect_match(tail(output, 1L), "Busca: 00:04:10.*Total: 00:16:40")
      testthat::expect_equal(reads, 3L)
      progress$stage("Coleta Hugging Face")
      now <- 1300; progress$tick()
      testthat::expect_match(tail(output, 1L), "Etapa: 00:05:00.*Total: 00:21:40")
      now <- 172800; progress$finish("Execução concluída")
      testthat::expect_match(tail(output, 1L), "Total: 2d 00:00:00")
      testthat::expect_false(any(grepl("[\r\033]", output)))
    }),
    progress_terminal = function() testthat::test_that("animação reutiliza a linha e é limpa ao encerrar", {
      now <- 0; output <- character()
      progress <- ConsoleProgress$new(clock = function() now, terminal = TRUE,
        write = function(text) output <<- c(output, text))
      progress$begin("Piloto limitado", 2L)
      progress$stage("Coleta GitHub")
      progress$scope("Busca 1/7: GDPR", "GDPR")
      progress$activity("Coletando comentários")
      now <- 0.3; progress$tick()
      now <- 0.6; progress$tick()
      frames <- output[grepl("\r", output, fixed = TRUE) & grepl("Total:", output, fixed = TRUE)]
      testthat::expect_true(length(unique(frames)) >= 2L)
      testthat::expect_true(all(startsWith(frames, "\r\033[2K")))
      progress$scope("Busca 2/7: General Data Protection Regulation", "General Data Protection Regulation")
      progress$activity("Coletando comentários")
      now <- 0.9; progress$tick()
      frame <- tail(output[grepl("\r", output, fixed = TRUE) & grepl("Total:", output, fixed = TRUE)], 1L)
      testthat::expect_match(frame, "Coletando")
      progress$finish("Piloto concluído")
      testthat::expect_match(tail(output, 1L), "Piloto concluído.*Total:")
      baseline <- length(output)
      now <- 600; progress$tick()
      testthat::expect_length(output, baseline)
    }),
    progress_waits = function() testthat::test_that("avisos e animação preservam tentativas, cotas e tempo de espera", {
      fixture <- private$factory$create(); on.exit(fixture$cleanup(), add = TRUE)
      fixture$store$start("github")
      now <- 0; calls <- 0L; output <- character()
      progress <- ConsoleProgress$new(clock = function() now, terminal = FALSE,
        write = function(text) output <<- c(output, text))
      progress$begin("Execução completa", 4L)
      progress$stage("Coleta GitHub")
      progress$scope("Busca 1/7: GDPR", "GDPR")
      http <- HttpClient$new("github", fixture$config, fixture$store,
        function(url, headers, timeout) {
          calls <<- calls + 1L
          status <- c(503L, 429L, 200L)[[calls]]
          private$factory$response(list(ok = TRUE), status, list(`retry-after` = "605"))
        }, function() now, function(seconds) now <<- now + seconds, progress = progress)
      testthat::expect_true(http$get("https://api.github.com/test")$data$ok)
      testthat::expect_equal(now, 608)
      testthat::expect_equal(fixture$store$query("SELECT status FROM responses ORDER BY rowid")$status, c(503L, 429L, 200L))
      text <- paste(output, collapse = "")
      testthat::expect_match(text, "HTTP 503.*2/5")
      testthat::expect_match(text, "Aguardando renovação.*00:10:06")
      testthat::expect_match(text, "coleta retomada")
      testthat::expect_equal(sum(grepl("^Progresso", output)), 2L)
      testthat::expect_match(tail(output[grepl("^Progresso", output)], 1L), "Busca: 00:10:02.*Total: 00:10:02")
      testthat::expect_false(any(grepl("[\r\033]", output)))
    }),
    progress_application = function() testthat::test_that("execução completa mostra quatro etapas, total desde a entrada e site sem ruído", {
      root <- tempfile("privacy-progress-app-"); dir.create(root)
      on.exit(unlink(root, recursive = TRUE), add = TRUE)
      file.copy(private$config$path("config"), root, recursive = TRUE)
      osi <- private$config$osi
      osi$licenses <- Filter(function(x) x$id == "MIT", osi$licenses)
      writeLines(ProtocolTools$new()$json(osi), file.path(root, "config/osi-licenses.json"))
      dir.create(file.path(root, "site"))
      writeLines("Coleta: {{DISCUSSIONS}}", file.path(root, "site/index-template.md"))
      dir.create(file.path(root, "inputs/reference"), recursive = TRUE)
      file.copy(private$config$path("inputs/reference/literature_methods.md"), file.path(root, "inputs/reference"))
      dir.create(file.path(root, "bin"))
      quarto <- file.path(root, "bin/quarto")
      writeLines(c("#!/bin/sh", 'mkdir -p "$2/_site"',
        'printf "<html>fixture</html>\\n" > "$2/_site/index.html"',
        'printf "Mensagem interna do render\\n"'), quarto)
      Sys.chmod(quarto, "0755")
      old_path <- Sys.getenv("PATH")
      on.exit(Sys.setenv(PATH = old_path), add = TRUE)
      Sys.setenv(PATH = paste(file.path(root, "bin"), old_path, sep = .Platform$path.sep))
      now <- 0; output <- character()
      progress <- ConsoleProgress$new(clock = function() now, terminal = FALSE,
        write = function(text) output <<- c(output, text))
      mock <- MockHubTransport$new(private$factory)
      factory <- function(platform, config, store) {
        HttpClient$new(platform, config, store, function(url, headers, timeout) {
          now <<- now + 1
          mock$perform(url, headers, timeout)
        }, function() now, function(seconds) now <<- now + seconds)
      }
      app <- ProjectApplication$new(root, private$environment, factory, progress, started = -120)
      app$run("--run")
      text <- paste(output, collapse = "")
      testthat::expect_match(text, "\\[1/4\\] Coleta GitHub")
      testthat::expect_match(text, "\\[2/4\\] Coleta Hugging Face")
      testthat::expect_match(text, "\\[3/4\\] Preparação dos CSVs e amostra")
      testthat::expect_match(text, "\\[4/4\\] Geração do site")
      testthat::expect_match(tail(output, 1L), "Execução concluída.*Total: 00:02:")
      testthat::expect_match(text, "Site gerado:")
      testthat::expect_false(grepl("Mensagem interna", text))
      testthat::expect_false(grepl("geração do site falhou", text))
      testthat::expect_false(any(grepl("[\r\033]", output)))
      testthat::expect_true(file.exists(file.path(root, "_site/index.html")))
      testthat::expect_equal(nrow(utils::read.csv(file.path(root, "inputs/final/collection/sample.csv"))), 10L)
      testthat::expect_false(dir.exists(file.path(root, ".run-lock")))
    }),
    structure = function() testthat::test_that("uma classe por arquivo, objetos bloqueados e complexidade limitada", {
      files <- list.files(private$config$path("src"), "\\.R$", recursive = TRUE, full.names = TRUE)
      for (file in files) {
        expression <- parse(file)
        testthat::expect_equal(length(expression), 1L, info = file)
        testthat::expect_true(grepl("R6::R6Class", paste(readLines(file), collapse = "\n"), fixed = TRUE), info = file)
      }
      bootstrap <- new.env(parent = private$environment)
      sys.source(private$config$path("src/bootstrap.R"), bootstrap)
      classes <- c(as.list(private$environment), as.list(bootstrap))
      for (name in names(classes)) {
        class <- classes[[name]]
        if (!inherits(class, "R6ClassGenerator") || name %in% c("ProtocolContractTests", "RQ3ContractTests", "MockHubTransport", "FixtureFactory")) next
        testthat::expect_true(class$lock_objects, info = name)
        testthat::expect_true(class$is_locked(), info = name)
        constructor <- class$public_methods$initialize
        if (!is.null(constructor)) testthat::expect_true(length(formals(constructor)) <= 8L, info = name)
        for (group in c("public_methods", "private_methods")) {
          for (method in names(class[[group]])) {
            testthat::expect_true(cyclocomp::cyclocomp(class[[group]][[method]]) <= 15L, info = paste(name, method))
          }
        }
      }
      tools <- ProtocolTools$new()
      testthat::expect_error(tools$surprise <- 1, "locked")
    })
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
