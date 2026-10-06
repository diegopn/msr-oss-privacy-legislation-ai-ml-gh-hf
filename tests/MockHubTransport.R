MockHubTransport <- R6::R6Class("MockHubTransport",
  public = list(
    requests = NULL,
    initialize = function(factory) {
      private$factory <- factory
      self$requests <- character()
    },
    perform = function(url, headers, timeout) {
      self$requests <- c(self$requests, url)
      if (startsWith(url, "https://api.github.com/")) return(private$github(url))
      if (startsWith(url, "https://huggingface.co/")) return(private$hf(url))
      stop("Testes não permitem requisições externas")
    }
  ),
  private = list(
    factory = NULL,
    github = function(url) {
      if (grepl("/search/issues?", url, fixed = TRUE)) {
        items <- lapply(1:4, private$issue)
        return(private$factory$response(list(total_count = 4L, incomplete_results = FALSE, items = items)))
      }
      if (grepl("/comments?", url, fixed = TRUE)) {
        items <- list(list(id = 10L, created_at = "2022-01-01T00:00:00Z", body = "CCPA CPRA consent", user = list(type = "Bot")),
          list(id = 11L, created_at = "2026-09-23T00:00:00Z", body = "GDPR"),
          list(id = 12L, body = "GDPR"),
          list(id = 13L, created_at = "2022-01-01T00:00:00Z", body = "right to erasure"))
        return(private$factory$response(items))
      }
      if (endsWith(url, "/contents")) return(private$factory$response(list(
        list(name = "requirements.txt", url = "https://api.github.com/repos/org/demo/contents/requirements.txt"))))
      if (endsWith(url, "/requirements.txt")) return(private$factory$response(
        list(encoding = "base64", content = jsonlite::base64_enc(charToRaw("torch\nnumpy")))))
      if (endsWith(url, "/repos/org/demo")) return(private$factory$response(list(name = "demo",
        created_at = "2017-01-01T00:00:00Z", private = FALSE, disabled = FALSE,
        topics = list("machine-learning"), license = list(spdx_id = "MIT"), archived = TRUE, fork = TRUE)))
      stop("Rota GitHub simulada desconhecida: ", url)
    },
    issue = function(index) {
      list(id = index, number = index, title = "Data handling", body = "GDPR",
        state = "closed", created_at = if (index == 4L) "2026-09-23T00:00:00Z" else "2019-01-01T00:00:00Z",
        repository_url = "https://api.github.com/repos/org/demo",
        comments_url = paste0("https://api.github.com/repos/org/demo/issues/", index, "/comments"),
        html_url = paste0("https://github.com/org/demo/issues/", index), comments = 4L,
        user = list(type = if (index == 2L) "Bot" else "User", login = "person"),
        pull_request = if (index == 3L) list(url = "pr") else NULL)
    },
    hf = function(url) {
      if (grepl("?filter=", url, fixed = TRUE)) return(private$factory$response(list(list(id = "org/demo"))))
      if (grepl("/resolve/main/README.md", url, fixed = TRUE)) return(private$factory$response(text =
        "---\nlicense: mit\ntask_categories: [text-classification]\n---\nGDPR in card is not a discussion."))
      if (grepl("/discussions?p=", url, fixed = TRUE)) return(private$factory$response(list(start = 0L, count = 3L,
        discussions = list(list(num = 1L, createdAt = "2022-01-01T00:00:00Z", isPullRequest = FALSE, status = "closed", author = list(name = "person", type = "user")),
          list(num = 2L, createdAt = "2022-01-01T00:00:00Z", isPullRequest = TRUE, status = "closed", author = list(name = "person", type = "user")),
          list(num = 3L, createdAt = "2026-09-23T00:00:00Z", isPullRequest = FALSE, status = "closed", author = list(name = "person", type = "user"))))))
      if (endsWith(url, "/discussions/1")) return(private$factory$response(list(num = 1L, title = "Privacy",
        createdAt = "2022-01-01T00:00:00Z", isPullRequest = FALSE, status = "closed", author = list(name = "person", type = "user"),
        events = list(list(id = "event1", createdAt = "2022-01-02T00:00:00Z", type = "comment", data = list(latest = list(raw = "GDPR CCPA CPRA Data Protection Act consent"))),
          list(id = "event2", createdAt = "2026-09-23T00:00:00Z", data = list(content = "GDPR")),
          list(id = "event3", data = list(content = "GDPR"))))))
      private$factory$response(list(id = "org/demo", createdAt = "2021-01-01T00:00:00Z", private = FALSE,
        gated = FALSE, disabled = FALSE, pipeline_tag = "text-generation", library_name = "transformers",
        cardData = list(license = "mit")))
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
