HuggingFaceClient <- R6::R6Class("HuggingFaceClient",
  public = list(
    initialize = function(http, config, store) {
      private$http <- http
      private$config <- config
      private$store <- store
      private$tools <- ProtocolTools$new()
      private$pages <- Pagination$new(http, store)
      private$license <- LicensePolicy$new(config$osi)
      private$ai <- AIClassifier$new(config)
    },
    walk_discovery = function(type, license, consumer) {
      private$http$progress$activity("Descobrindo projetos")
      private$pages$walk(private$discovery_url(type, license), consumer, bucket = "pages")
    },
    repository = function(type, item) {
      private$http$progress$activity("Avaliando repositórios")
      id <- private$tools$scalar(item$id, private$tools$scalar(item$modelId))
      if (!nzchar(id)) {
        private$store$problem("invalid_repository_response", "Hugging Face discovery",
          "Projeto sem identificador; item descartado")
        return(NULL)
      }
      url <- self$api_url(type, id)
      metadata <- if (private$valid_metadata(item)) item else list(id = id)
      available <- private$complete_metadata(item)
      if (!available) {
        detail <- private$detail(url)
        available <- !is.null(detail)
        if (available) metadata <- utils::modifyList(metadata, detail$data)
      }
      if (!available) private$store$unavailable(id, "repository_unavailable")
      card <- if (available && private$readable(metadata) && !private$confirmed(metadata)) private$card(type, id) else list()
      license <- private$licenses(metadata, card)
      list(key = private$tools$key("huggingface", type, id), platform = "huggingface",
        type = type, id = id, created = private$tools$scalar(metadata$createdAt),
        private = metadata$private, gated = metadata$gated, disabled = metadata$disabled,
        available = available, license = license, metadata = metadata, card = card)
    },
    discussions = function(repo, limit = Inf) {
      private$http$progress$activity("Buscando Discussions")
      output <- list()
      page <- 0L
      previous_start <- -1L
      repeat {
        url <- paste0(self$api_url(repo$type, repo$id), "/discussions?p=", page, "&type=discussion")
        response <- private$http$get(url, "pages", optional = "discussions")
        if (is.null(response)) {
          private$store$unavailable(url, "discussions_unavailable")
          return(output)
        }
        data <- response$data
        if (!private$validate_page(data, previous_start, url)) return(output)
        previous_start <- data$start
        output <- c(output, data$discussions)
        if (data$start + length(data$discussions) >= data$count || length(output) >= limit) break
        page <- page + 1L
      }
      head(output, min(limit, length(output)))
    },
    discussion = function(repo, number) {
      private$http$progress$activity("Coletando discussão e comentários")
      url <- paste0(self$api_url(repo$type, repo$id), "/discussions/", number)
      response <- private$http$get(url, optional = TRUE)
      if (is.null(response)) {
        private$store$unavailable(url, "discussion_unavailable")
        return(NULL)
      }
      if (!is.list(response$data)) {
        private$store$problem("invalid_discussion_response", url, "Detalhes não são um objeto JSON")
        return(NULL)
      }
      events <- response$data$events
      if (!is.null(events) && (!is.list(events) || !all(vapply(events, is.list, logical(1))))) {
        private$store$problem("invalid_discussion_response", url, "Eventos não são uma lista JSON válida")
        return(NULL)
      }
      response$data
    },
    api_url = function(type, id) paste0("https://huggingface.co/api/", type, "s/", id)
  ),
  private = list(
    http = NULL, config = NULL, store = NULL, tools = NULL, pages = NULL, license = NULL, ai = NULL,
    complete_metadata = function(metadata) {
      if (!private$valid_metadata(metadata)) return(FALSE)
      time <- TimePolicy$new(private$config$settings$protocol$cutoff)
      flag <- function(value) is.logical(value) && length(value) == 1L && !is.na(value)
      !is.na(time$parse(metadata$createdAt)) && flag(metadata$private) && flag(metadata$disabled) &&
        (flag(metadata$gated) || identical(metadata$gated, "auto") || identical(metadata$gated, "manual"))
    },
    valid_metadata = function(metadata) {
      is.list(metadata) && (is.null(metadata$cardData) || is.list(metadata$cardData))
    },
    detail = function(url) {
      response <- private$http$get(url, optional = TRUE)
      if (!is.null(response) && !private$valid_metadata(response$data)) {
        private$store$problem("invalid_repository_response", url, "Metadados ausentes ou com campos estruturados inválidos")
        return(NULL)
      }
      response
    },
    confirmed = function(metadata) {
      length(private$licenses(metadata, list())) > 0L &&
        private$ai$huggingface(metadata)$status == "eligible"
    },
    valid_discussion_page = function(data) {
      if (!is.list(data)) return(FALSE)
      if (!private$valid_page_number(data$start) || !private$valid_page_number(data$count)) return(FALSE)
      is.list(data$discussions) && all(vapply(data$discussions, is.list, logical(1)))
    },
    valid_page_number = function(value) is.numeric(value) && length(value) == 1L && is.finite(value) && value >= 0,
    invalid_discussion_cursor = function(data, previous) {
      data$start <= previous || (!length(data$discussions) && data$start < data$count)
    },
    discovery_url = function(type, license) {
      properties <- c("createdAt", "private", "gated", "disabled", "cardData", "tags")
      if (type == "model") properties <- c(properties, "pipeline_tag", "library_name")
      paste0("https://huggingface.co/api/", type, "s?filter=license:",
        utils::URLencode(license, reserved = TRUE), "&limit=", private$config$settings$http$page_size,
        paste0("&expand=", properties, collapse = ""))
    },
    readable = function(metadata) {
      time <- TimePolicy$new(private$config$settings$protocol$cutoff)
      identical(metadata$private, FALSE) && identical(metadata$gated, FALSE) &&
        !isTRUE(metadata$disabled) && time$eligible(metadata$createdAt)
    },
    card = function(type, id) {
      prefix <- if (type == "dataset") "datasets/" else ""
      url <- paste0("https://huggingface.co/", prefix, id, "/resolve/main/README.md")
      response <- private$http$get(url, "resolvers", optional = TRUE)
      if (is.null(response)) return(list())
      lines <- strsplit(response$text, "\n", fixed = TRUE)[[1L]]
      lines[[1L]] <- sub("^\ufeff", "", lines[[1L]])
      if (!identical(trimws(lines[[1L]]), "---")) return(list())
      delimiters <- which(trimws(lines[-1L]) == "---") + 1L
      if (!length(delimiters)) return(list())
      tryCatch(yaml::yaml.load(paste(lines[seq.int(2L, delimiters[[1L]] - 1L)], collapse = "\n"), eval.expr = FALSE),
        error = function(e) {
          private$store$problem("invalid_card_yaml", url, conditionMessage(e))
          list()
        })
    },
    licenses = function(metadata, card) {
      candidates <- metadata$license
      if (is.null(candidates)) candidates <- metadata$cardData$license
      if (is.null(candidates)) candidates <- card$license
      if (is.null(candidates)) {
        tags <- unlist(metadata$tags, use.names = FALSE)
        candidates <- sub("^license:", "", tags[grepl("^license:", tags)])
      }
      if (!length(candidates)) return(NULL)
      vapply(unlist(candidates, use.names = FALSE), private$license$canonical, "")
    },
    validate_page = function(data, previous, url) {
      if (!private$valid_discussion_page(data) || private$invalid_discussion_cursor(data, previous)) {
        private$store$problem("invalid_discussion_cursor", url, "Página ausente, vazia ou repetida")
        return(FALSE)
      }
      TRUE
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
