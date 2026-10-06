GitHubSearch <- R6::R6Class("GitHubSearch",
  public = list(
    initialize = function(http, config, store) {
      private$http <- http
      private$config <- config
      private$store <- store
      private$time <- TimePolicy$new(config$settings$protocol$cutoff)
      private$pagination <- Pagination$new(http, store)
    },
    walk = function(term, start, consumer, limit = Inf) {
      private$count <- 0L
      private$seen <- new.env(parent = emptyenv())
      private$terms <- unlist(term, use.names = FALSE)
      private$window(paste(private$terms, collapse = " / "), private$time$parse(start), private$time$end - 1,
                     consumer, limit)
      invisible(private$count)
    }
  ),
  private = list(
    http = NULL, config = NULL, store = NULL, time = NULL, pagination = NULL, count = 0L, terms = NULL, seen = NULL,
    url = function(from, to, page) {
      phrase <- paste0('"', private$terms, '"', collapse = " OR ")
      if (length(private$terms) > 1L) phrase <- paste0("(", phrase, ")")
      query <- paste0(phrase, ' is:issue is:closed is:public in:title,body,comments created:',
                      private$time$stamp(from), "..", private$time$stamp(to))
      paste0("https://api.github.com/search/issues?q=", utils::URLencode(query, reserved = TRUE),
             "&sort=created&order=asc&per_page=", private$config$settings$http$page_size,
             "&page=", page)
    },
    window = function(term, from, to, consumer, limit) {
      if (private$count >= limit) return(invisible(NULL))
      private$http$progress$activity("Buscando issues")
      first <- private$http$get(private$url(from, to, 1L), "search")
      if (is.null(first)) {
        private$store$problem("search_request_failed", term,
          paste("Busca sem resposta verificável no intervalo UTC", private$time$stamp(from), "a", private$time$stamp(to)))
        return(invisible(NULL))
      }
      if (!private$validate_search_response(first, term)) return(invisible(NULL))
      private$collect_window(term, from, to, first, consumer, limit)
    },
    collect_window = function(term, from, to, first, consumer, limit) {
      if (first$data$total_count > 1000L || isTRUE(first$data$incomplete_results)) {
        private$split(term, from, to, consumer, limit)
        return(invisible(NULL))
      }
      items <- private$pages(term, from, to, first, limit)
      if (inherits(items, "unverifiable_search_page")) return(invisible(NULL))
      if (is.null(items) || inherits(items, "empty_search_page")) {
        private$recover_window(term, from, to, items, consumer, limit)
        return(invisible(NULL))
      }
      private$consume(items, consumer, limit)
    },
    recover_window = function(term, from, to, items, consumer, limit) {
      if (from >= to) return(private$leaf(term, from, consumer, limit, items))
      private$split(term, from, to, consumer, limit)
    },
    split = function(term, from, to, consumer, limit) {
      if (from >= to) {
        private$leaf(term, from, consumer, limit)
        return(invisible(NULL))
      }
      middle <- from + floor(as.numeric(difftime(to, from, units = "secs")) / 2)
      private$window(term, from, middle, consumer, limit)
      private$window(term, middle + 1, to, consumer, limit)
    },
    leaf = function(term, from, consumer, limit, items = NULL) {
      if (length(private$terms) == 1L) return(private$record_gap(term, from, items))
      terms <- private$terms
      on.exit(private$terms <- terms, add = TRUE)
      for (single in terms) {
        private$terms <- single
        private$window(single, from, from, consumer, limit)
      }
      invisible(NULL)
    },
    unseen = function(items) {
      items[!vapply(items, function(item) exists(paste0("issue:", item$id), private$seen, inherits = FALSE), logical(1))]
    },
    pages = function(term, from, to, first, limit) {
      page <- 1L
      response <- first
      items <- list()
      seen <- character()
      empty_retries <- 0L
      repeat {
        current <- private$read_page(response, term, first$data, seen, length(items), page)
        if (current$status == "failed") return(private$failed_page())
        if (current$status == "changed_total") return(NULL)
        data <- current$data
        empty <- private$empty_response(from, to, page, first, data, empty_retries)
        if (inherits(empty, "empty_search_page")) return(empty)
        if (!is.null(empty)) {
          empty_retries <- 1L
          response <- empty
          next
        }
        seen <- c(seen, current$signature)
        items <- private$merge_items(items, data$items)
        state <- private$page_action(items, first$data$total_count, limit, page, response)
        if (state$done) return(state$items)
        page <- page + 1L
        private$http$progress$activity("Buscando issues")
        response <- private$http$get(private$url(from, to, page), "search")
      }
    },
    empty_response = function(from, to, page, first, data, retries) {
      if (page != 1L || length(data$items) || first$data$total_count == 0L) return(NULL)
      if (retries > 0L) return(structure(list(), class = "empty_search_page"))
      private$http$progress$activity("Confirmando resultado")
      private$http$get(private$url(from, to, page), "search")
    },
    merge_items = function(items, next_items) {
      merged <- c(items, next_items)
      ids <- vapply(merged, function(item) as.character(item$id), character(1))
      merged[!duplicated(ids)]
    },
    has_more_pages = function(page, response) {
      page * private$config$settings$http$page_size < 1000L &&
        !is.null(private$pagination$next_url(response$headers$link))
    },
    page_action = function(items, total, limit, page, response) {
      if (length(items) == total || private$count + length(private$unseen(items)) >= limit) {
        return(list(done = TRUE, items = items))
      }
      if (length(items) > total || !private$has_more_pages(page, response)) {
        return(list(done = TRUE, items = NULL))
      }
      list(done = FALSE, items = items)
    },
    validate_search_response = function(response, term) {
      if (private$valid_search_response(response)) return(TRUE)
      private$store$problem("invalid_search", term, "Resposta de busca sem total ou itens")
      FALSE
    },
    valid_search_response = function(response) {
      data <- response$data
      is.list(data) && private$valid_total(data$total_count) && is.list(data$items) &&
        private$json_object(response$text)
    },
    valid_total = function(value) {
      is.numeric(value) && length(value) == 1L && is.finite(value) && value >= 0
    },
    json_object = function(text) startsWith(trimws(text), "{"),
    record_gap = function(term, from, items) {
      empty <- inherits(items, "empty_search_page")
      code <- if (empty) "search_empty_second" else "search_saturated_second"
      detail <- if (empty) paste0("Intervalo UTC ", private$time$stamp(from),
        ": a busca informou resultados, mas continuou sem entregar itens após uma nova consulta") else
        paste("Intervalo UTC sem resultado verificável:", private$time$stamp(from))
      private$store$problem(code, term, detail, resolved = FALSE)
    },
    consume = function(items, consumer, limit) {
      for (item in private$unseen(items)) {
        if (private$count >= limit) return(invisible(NULL))
        private$seen[[paste0("issue:", item$id)]] <- TRUE
        consumer(item)
        private$count <- private$count + 1L
        private$http$progress$tick()
      }
    },
    failed_page = function() structure(list(), class = "unverifiable_search_page"),
    read_page = function(response, term, first, seen, received, page) {
      if (is.null(response)) {
        private$store$problem("search_page_failed", term, paste("Falha ao verificar a página", page))
        return(list(status = "failed"))
      }
      data <- response$data
      if (!is.list(data)) {
        private$store$problem("invalid_search_page", term, paste("Página", page, "não contém um objeto JSON"))
        return(list(status = "failed"))
      }
      signature <- digest::digest(data$items, algo = "sha256")
      valid <- private$validate_page(data, first, signature, seen, received, term, page)
      if (identical(valid, FALSE)) return(list(status = "failed"))
      if (identical(valid, "changed_total")) return(list(status = "changed_total"))
      list(status = "ok", data = data, signature = signature)
    },
    valid_page_items = function(items) {
      is.list(items) && all(vapply(items, function(item) {
        is.list(item) && length(item$id) == 1L && !is.null(item$id)
      }, logical(1)))
    },
    valid_page_total = function(value) private$valid_total(value),
    repeated_page = function(signature, seen, page, items, received, total) {
      signature %in% seen || (page != 1L && length(items) == 0L && received < total)
    },
    validate_page = function(response, first, signature, seen, received, term, page) {
      items <- response$items
      if (isTRUE(response$incomplete_results)) {
        private$store$problem("incomplete_search_page", term, paste("Página", page))
        return(FALSE)
      }
      if (!private$valid_page_total(response$total_count) || !private$valid_page_items(items)) {
        private$store$problem("invalid_search_page", term, "Página inválida, repetida ou vazia antes do total")
        return(FALSE)
      }
      if (response$total_count != first$total_count) return("changed_total")
      if (private$repeated_page(signature, seen, page, items, received, first$total_count)) {
        private$store$problem("invalid_search_page", term, "Página inválida, repetida ou vazia antes do total")
        return(FALSE)
      }
      TRUE
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
