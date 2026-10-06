PopulationBuilder <- R6::R6Class("PopulationBuilder",
  public = list(
    initialize = function(store) private$store <- store,
    build = function() {
      private$store$query(paste(
        "SELECT DISTINCT a.artifact_key AS unit_key,a.repo_key,a.platform,r.repo_type,e.label AS law,a.url,a.created",
        "FROM artifacts a JOIN repositories r ON a.repo_key=r.repo_key",
        "JOIN evidences e ON e.unit_key=a.artifact_key",
        "WHERE a.kind IN ('issue','discussion') AND e.kind='legal' AND r.status='eligible'",
        "ORDER BY a.platform,r.repo_type,e.label,a.artifact_key"))
    },
    texts = function(unit_key) {
      artifacts <- private$store$query("SELECT kind,created,text FROM artifacts WHERE unit_key=? ORDER BY created,artifact_key",
                                       list(unit_key))
      paste(paste(artifacts$kind, artifacts$created, artifacts$text, sep = "\n"), collapse = "\n\n")
    },
    sources = function(units) {
      sql <- paste("SELECT artifact_key,unit_key,repo_key,platform,kind,created,text,url,payload FROM artifacts WHERE",
        if (length(units)) paste0("unit_key IN (", paste(rep("?", length(units)), collapse = ","), ")") else "0",
        "ORDER BY unit_key,created,artifact_key")
      rows <- private$store$query(sql, if (length(units)) as.list(units) else NULL)
      rows$event_type <- vapply(rows$payload, function(value)
        ProtocolTools$new()$scalar(ProtocolTools$new()$decode(value)$metadata$type), "")
      rows$source_role <- rep("", nrow(rows))
      for (i in seq_len(nrow(rows))) rows$source_role[i] <- private$role(rows[i, ], rows)
      rows$payload <- NULL
      rows
    }
  ), private = list(
    store = NULL,
    role = function(row, sources) {
      if (row$kind == "issue") return("initial")
      if (row$kind == "discussion") return("initial_title")
      if (row$kind == "comment") return("comment_context")
      main <- sources[sources$artifact_key == row$unit_key, , drop = FALSE]
      events <- sources[sources$unit_key == row$unit_key & sources$kind == "event" & sources$event_type == "comment", , drop = FALSE]
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
  ),
  lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
