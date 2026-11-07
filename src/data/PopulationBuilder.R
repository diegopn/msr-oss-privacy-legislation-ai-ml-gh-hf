PopulationBuilder <- R6::R6Class("PopulationBuilder",
  public = list(
    initialize = function(store) private$stores <- PlatformStores$new(store),
    build = function() {
      rows <- lapply(c("github", "huggingface"), function(platform) {
        private$stores$for_platform(platform)$query(paste(
          "SELECT DISTINCT a.artifact_key AS unit_key,a.repo_key,a.platform,r.repo_type,e.label AS law,a.url,a.created",
          "FROM artifacts a JOIN repositories r ON a.repo_key=r.repo_key",
          "JOIN evidences e ON e.unit_key=a.artifact_key",
          "WHERE a.platform=? AND a.kind IN ('issue','discussion') AND e.kind='legal' AND r.status='eligible'",
          "ORDER BY a.platform,r.repo_type,e.label,a.artifact_key"), list(platform))
      })
      private$bind_rows(rows, data.frame(unit_key = character(), repo_key = character(), platform = character(),
        repo_type = character(), law = character(), url = character(), created = character()))
    },
    texts = function(unit_key, platform = NULL) {
      platforms <- if (is.null(platform)) c("github", "huggingface") else platform
      rows <- lapply(platforms, function(item) private$stores$for_platform(item)$query(
        "SELECT kind,created,text FROM artifacts WHERE unit_key=? AND platform=? ORDER BY created,artifact_key",
        list(unit_key, item)))
      artifacts <- private$bind_rows(rows, data.frame(kind = character(), created = character(), text = character()))
      paste(paste(artifacts$kind, artifacts$created, artifacts$text, sep = "\n"), collapse = "\n\n")
    },
    sources = function(units) {
      rows <- lapply(c("github", "huggingface"), function(platform) {
        if (is.data.frame(units)) {
          if (!all(c("unit_key", "platform") %in% names(units))) {
            stop("A amostra precisa identificar unidade e plataforma.", call. = FALSE)
          }
          selected <- unique(as.character(units$unit_key[units$platform == platform]))
        } else selected <- as.character(units)
        sql <- paste("SELECT artifact_key,unit_key,repo_key,platform,kind,created,text,url,payload FROM artifacts WHERE",
          if (length(selected)) paste0("platform=? AND unit_key IN (", paste(rep("?", length(selected)), collapse = ","), ")") else "0",
          "ORDER BY platform,unit_key,created,artifact_key")
        params <- if (length(selected)) c(list(platform), as.list(selected)) else NULL
        private$stores$for_platform(platform)$query(sql, params)
      })
      rows <- private$bind_rows(rows, data.frame(artifact_key = character(), unit_key = character(),
        repo_key = character(), platform = character(), kind = character(), created = character(),
        text = character(), url = character(), payload = character()))
      tools <- ProtocolTools$new()
      rows$event_type <- vapply(rows$payload, function(value)
        tools$scalar(tools$decode(value)$metadata$type), "")
      rows$source_role <- rep("", nrow(rows))
      for (i in seq_len(nrow(rows))) rows$source_role[i] <- private$role(rows[i, ], rows)
      rows$payload <- NULL
      rows
    }
  ), private = list(
    stores = NULL,
    bind_rows = function(rows, empty) {
      rows <- Filter(function(value) nrow(value) > 0L, rows)
      if (length(rows)) return(do.call(rbind, rows))
      empty
    },
    role = function(row, sources) {
      if (row$kind == "issue") return("initial")
      if (row$kind == "discussion") return("initial_title")
      if (row$kind == "comment") return("comment_context")
      main <- sources[sources$artifact_key == row$unit_key & sources$platform == row$platform, , drop = FALSE]
      events <- sources[sources$unit_key == row$unit_key & sources$platform == row$platform &
        sources$kind == "event" & sources$event_type == "comment", , drop = FALSE]
      metadata <- ProtocolTools$new()$decode(row$payload)$metadata
      if (!identical(metadata$type, "comment")) return("event_context")
      if (row$artifact_key != events$artifact_key[1L]) return("comment_context")
      private$initial_hf(row, main, metadata)
    },
    initial_hf = function(row, main, event) {
      original <- ProtocolTools$new()$decode(main$payload)$metadata
      tools <- ProtocolTools$new()
      creator <- tools$scalar(if (is.list(original$author)) original$author$name else original$author)
      author <- tools$scalar(if (is.list(event$author)) event$author$name else event$author)
      if (nzchar(creator) && identical(creator, author) && identical(row$created, main$created)) return("initial")
      "unresolved_context"
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
