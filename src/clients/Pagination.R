Pagination <- R6::R6Class("Pagination",
  public = list(
    initialize = function(http, store) {
      private$http <- http
      private$store <- store
    },
    collect = function(url, bucket = "api", limit = Inf, optional = FALSE) {
      output <- list()
      result <- self$walk(url, function(item) { output[[length(output) + 1L]] <<- item },
                          bucket, limit, optional)
      if (is.null(result)) return(NULL)
      output
    },
    walk = function(url, consumer, bucket = "api", limit = Inf, optional = FALSE) {
      received <- 0L
      visited <- character()
      while (!is.null(url) && received < limit) {
        step <- private$step(url, bucket, optional, visited)
        if (step$stop) return(invisible(received))
        visited <- c(visited, url)
        response <- step$response
        data <- response$data
        for (item in data) {
          if (received >= limit) return(invisible(received))
          continue <- consumer(item)
          received <- received + 1L
          if (identical(continue, FALSE)) return(invisible(received))
        }
        url <- self$next_url(response$headers$link)
      }
      invisible(received)
    },
    next_url = function(link) {
      if (is.null(link) || !nzchar(link)) return(NULL)
      parts <- strsplit(link, ",", fixed = TRUE)[[1L]]
      next_link <- parts[grepl('rel="next"', parts, fixed = TRUE)]
      if (!length(next_link)) return(NULL)
      if (length(next_link) != 1L || !grepl("<https://[^>]+>", next_link)) {
        private$store$problem("invalid_cursor", link, "Cabeçalho Link inválido")
        return(NULL)
      }
      sub(".*<([^>]+)>.*", "\\1", next_link)
    }
  ), private = list(
    http = NULL, store = NULL,
    step = function(url, bucket, optional, visited) {
      if (!private$validate_cursor(url, visited)) return(list(stop = TRUE))
      response <- private$http$get(url, bucket, optional)
      if (is.null(response) || !private$validate_page(response, url)) return(list(stop = TRUE))
      list(stop = FALSE, response = response)
    },
    validate_cursor = function(url, visited) {
      if (url %in% visited) {
        private$store$problem("repeated_cursor", url, "Cursor repetido")
        return(FALSE)
      }
      TRUE
    },
    validate_page = function(response, url) {
      if (is.null(response$data) || !is.list(response$data) ||
          !all(vapply(response$data, is.list, logical(1))) || !startsWith(trimws(response$text), "[")) {
        private$store$problem("invalid_page", url, "Listagem JSON ausente")
        return(FALSE)
      }
      TRUE
    }
  ),
  lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
