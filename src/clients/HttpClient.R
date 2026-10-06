HttpClient <- R6::R6Class("HttpClient",
  public = list(
    progress = NULL,
    initialize = function(platform, config, store, transport = NULL, clock = NULL, sleep = NULL, progress = NULL) {
      private$platform <- platform
      private$config <- config$settings$http
      private$store <- store
      private$transport <- if (is.null(transport)) private$perform else transport
      private$clock <- if (is.null(clock)) function() as.numeric(Sys.time()) else clock
      private$sleep <- if (is.null(sleep)) Sys.sleep else sleep
      private$last <- new.env(parent = emptyenv())
      private$token <- Sys.getenv(if (platform == "github") "GITHUB_TOKEN" else "HF_TOKEN")
      self$progress <- if (is.null(progress)) ConsoleProgress$new(enabled = FALSE) else progress
    },
    get = function(url, bucket = "api", optional = FALSE) {
      if (!private$validate_url(url)) return(NULL)
      if (bucket %in% c("api", "resolvers") && !grepl("/(search|issues|discussions)(/|\\?)", url)) {
        cached <- private$store$replay(url)
        if (!is.null(cached)) {
          value <- private$decode(cached, url)
          if (!is.null(value)) {
            private$store$response(url, cached, 0L)
            self$progress$tick()
            return(value)
          }
        }
      }
      outcome <- private$retry_get(url, bucket, optional)
      if (outcome$done) return(outcome$value)
      result <- outcome$result
      private$store$problem("http_failure", url, paste("HTTP", result$status))
      NULL
    }
  ),
  private = list(
    platform = NULL, config = NULL, store = NULL, transport = NULL, clock = NULL,
    sleep = NULL, token = NULL, last = NULL, quota_started = NULL,
    retry_get = function(url, bucket, optional) {
      failures <- 0L
      quota_retries <- 0L
      attempts <- 0L
      started <- NULL
      if (private$platform == "huggingface") private$quota_started <- NULL
      repeat {
        private$throttle(bucket)
        attempts <- attempts + 1L
        result <- private$request(url, attempts)
        if (private$is_quota(result)) {
          quota_retries <- quota_retries + 1L
          if (!private$quota_wait(result, quota_retries)) return(list(done = TRUE, value = NULL))
          next
        }
        ready <- private$ready(result, url, optional)
        if (ready$done) return(ready)
        if (!result$status %in% c(0L, 408L, 425L, 500L, 502L, 503L, 504L)) break
        failures <- failures + 1L
        if (is.null(started)) started <- private$clock()
        delay <- min(2 ^ failures, 30)
        if (!private$can_retry(failures, started, delay)) break
        self$progress$event(paste0(private$platform, ": falha temporária HTTP ", result$status,
          "; nova tentativa ", failures + 1L, "/", private$config$attempts,
          " em ", self$progress$duration(delay), "."))
        self$progress$wait(delay, private$sleep, private$clock, "Nova tentativa")
      }
      list(done = FALSE, result = result)
    },
    can_retry = function(failures, started, delay) {
      failures < private$config$attempts && private$clock() - started + delay <= private$config$retry_budget
    },
    ready = function(result, url, optional) {
      if (result$status >= 200L && result$status < 300L) return(list(done = TRUE, value = private$decode(result, url)))
      if (private$unavailable(result, optional)) return(list(done = TRUE, value = NULL))
      list(done = FALSE)
    },
    unavailable = function(result, optional) {
      if (identical(optional, FALSE)) return(FALSE)
      if (result$status %in% c(404L, 410L)) return(TRUE)
      if (!identical(optional, "discussions") || result$status != 403L) return(FALSE)
      text <- if (is.raw(result$body)) rawToChar(result$body) else result$body
      grepl("discussions? (are |is )?disabled", text, ignore.case = TRUE, perl = TRUE)
    },
    validate_url = function(url) {
      domain <- if (private$platform == "github") "api.github.com" else "huggingface.co"
      prefix <- paste0("https://", domain, "/")
      valid <- is.character(url) && length(url) == 1L && !is.na(url) &&
        startsWith(url, prefix) && !grepl("[\\r\\n]", url, perl = TRUE)
      if (!valid) {
        private$store$problem("invalid_cursor", as.character(url), "URL fora do domínio da API")
        return(FALSE)
      }
      TRUE
    },
    throttle = function(bucket) {
      interval <- if (private$platform == "github") {
        if (bucket == "search") private$config$github_search_interval else 0
      } else private$config$hf_intervals[[bucket]]
      previous <- private$last[[bucket]]
      if (!is.null(previous)) self$progress$wait(max(0, previous + interval - private$clock()), private$sleep, private$clock)
      private$last[[bucket]] <- private$clock()
    },
    request = function(url, number) {
      headers <- list(Accept = "application/json", `User-Agent` = "privacy-legislation-research/1.0")
      if (nzchar(private$token)) headers$Authorization <- paste("Bearer", private$token)
      if (private$platform == "github") headers[["X-GitHub-Api-Version"]] <- "2026-03-10"
      self$progress$tick()
      result <- tryCatch(private$transport(url, headers, private$config$timeout),
                         error = function(error) list(status = 0L, headers = list(), body = raw(),
                                                       error = private$error_text(error)))
      result$headers <- unclass(as.list(result$headers))
      names(result$headers) <- tolower(names(result$headers))
      private$store$attempt(url, number, result$status, ProtocolTools$new()$scalar(result$error))
      private$store$response(url, result, number)
      self$progress$tick()
      result
    },
    error_text = function(error) {
      text <- conditionMessage(error)
      if (nzchar(private$token)) text <- gsub(private$token, "[REDACTED]", text, fixed = TRUE)
      text
    },
    perform = function(url, headers, timeout) {
      request <- httr2::request(url)
      request <- do.call(httr2::req_headers, c(list(request), headers))
      request <- httr2::req_timeout(request, timeout)
      request <- httr2::req_error(request, is_error = function(response) FALSE)
      if (self$progress$enabled) request <- httr2::req_options(request, noprogress = FALSE,
        xferinfofunction = function(down, up) self$progress$tick())
      response <- httr2::req_perform(request)
      list(status = httr2::resp_status(response), headers = as.list(httr2::resp_headers(response)),
           body = httr2::resp_body_raw(response))
    },
    decode = function(result, url) {
      content_type <- ProtocolTools$new()$scalar(result$headers[["content-type"]])
      body <- result$body
      if (is.raw(body)) {
        nul <- which(body == as.raw(0L))
        if (length(nul)) {
          if (grepl("json", content_type, fixed = TRUE)) {
            private$store$problem("invalid_json", url, "Resposta JSON contém byte NUL")
            return(NULL)
          }
          body <- if (nul[[1L]] > 1L) body[seq_len(nul[[1L]] - 1L)] else raw()
        }
        text <- rawToChar(body)
      } else text <- body
      data <- if (grepl("json", content_type, fixed = TRUE)) {
             tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) {
               private$store$problem("invalid_json", url, conditionMessage(e))
               NULL
             })
           } else NULL
      if (grepl("json", content_type, fixed = TRUE) && is.null(data)) return(NULL)
      list(text = text, headers = result$headers, status = result$status, data = data)
    },
    is_quota = function(result) {
      if (result$status == 429L) return(TRUE)
      if (result$status != 403L || private$platform != "github") return(FALSE)
      headers <- result$headers
      body <- if (is.raw(result$body)) rawToChar(result$body) else result$body
      identical(headers[["x-ratelimit-remaining"]], "0") ||
        !is.null(headers[["retry-after"]]) || grepl("rate limit", body, ignore.case = TRUE)
    },
    quota_wait = function(result, retries) {
      now <- private$clock()
      if (is.null(private$quota_started)) private$quota_started <- now
      github <- private$platform == "github"
      budget <- if (github) private$config$github_quota_budget else private$config$hf_quota_budget
      delay <- private$reset_delay(result$headers, retries)
      exhausted <- !github && retries > private$config$hf_quota_retries
      if (exhausted || now - private$quota_started + delay > budget) {
        private$store$problem("quota_budget", private$platform, "Orçamento de espera esgotado")
        return(FALSE)
      }
      self$progress$event(paste0(private$platform, ": Aguardando renovação da cota por ",
        self$progress$duration(delay), "."))
      self$progress$wait(delay, private$sleep, private$clock, "Aguardando cota")
      self$progress$event(paste0(private$platform, ": coleta retomada."))
      TRUE
    },
    reset_delay = function(headers, retries) {
      values <- c(private$retry_after(headers[["retry-after"]]),
                  suppressWarnings(as.numeric(headers[["x-ratelimit-reset"]])) - private$clock())
      rate <- ProtocolTools$new()$scalar(headers[["ratelimit"]])
      match <- regmatches(rate, regexpr("t=[0-9]+", rate))
      if (length(match) && nzchar(match)) values <- c(values, as.numeric(sub("t=", "", match)))
      values <- values[is.finite(values) & values >= 0]
      if (length(values)) return(max(values) + 1)
      min(30 * 2 ^ (retries - 1L), 300)
    },
    retry_after = function(value) {
      if (is.null(value)) return(numeric())
      numeric <- suppressWarnings(as.numeric(value))
      if (is.finite(numeric)) return(numeric)
      as.numeric(as.POSIXct(strptime(value, "%a, %d %b %Y %H:%M:%S GMT", tz = "UTC"))) - private$clock()
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
