AuditStore <- R6::R6Class("AuditStore",
  public = list(
    connection = NULL, run_id = NULL, path = NULL,
    initialize = function(path, config, recover = FALSE, readonly = FALSE) {
      self$path <- path
      private$config <- config
      private$tools <- ProtocolTools$new()
      private$recover <- recover
      private$readonly <- readonly
      private$cache <- new.env(parent = emptyenv())
      if (!readonly) dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      flags <- if (readonly) RSQLite::SQLITE_RO else RSQLite::SQLITE_RW
      if (!readonly && !file.exists(path)) flags <- RSQLite::SQLITE_RWC
      self$connection <- DBI::dbConnect(RSQLite::SQLite(), path, flags = flags)
      DBI::dbExecute(self$connection, "PRAGMA foreign_keys = ON")
      DBI::dbExecute(self$connection, "PRAGMA busy_timeout = 5000")
      if (!readonly) private$schema()
    },
    close = function() {
      if (DBI::dbIsValid(self$connection)) DBI::dbDisconnect(self$connection)
      invisible(TRUE)
    },
    query = function(sql, params = NULL) DBI::dbGetQuery(self$connection, sql, params = params),
    search_gap_codes = function(platform) {
      if (platform == "github") c("search_empty_second", "search_saturated_second") else character()
    },
    start = function(platform, pilot = FALSE) {
      private$pilot <- pilot
      private$recovery_context <- NULL
      private$recover_responses(platform)
      self$run_id <- paste0(format(Sys.time(), "%Y%m%dT%H%M%OS6", tz = "UTC"), "-", platform,
                            "-", Sys.getpid())
      DBI::dbExecute(self$connection, paste(
        "INSERT INTO runs(run_id,platform,pilot,status,cutoff,version,config_hash,started)",
        "VALUES(?,?,?,?,?,?,?,?)"), params = list(self$run_id, platform, as.integer(pilot), "running",
        private$config$settings$protocol$cutoff, private$config$settings$protocol$version,
        private$config$fingerprint, private$tools$now()))
      invisible(self$run_id)
    },
    replay = function(url) {
      record <- private$cache[[url]]
      if (is.null(record)) return(NULL)
      tryCatch({
        path <- private$config$path(record$path)
        if (!file.exists(path) || isTRUE(file.info(path)$isdir)) return(NULL)
        body <- readBin(path, "raw", n = file.info(path)$size)
        if (!identical(private$tools$hash(body), record$sha256)) return(NULL)
        list(status = record$status, headers = private$tools$decode(record$headers), body = body)
      }, error = function(error) NULL)
    },
    finish = function(status = NULL) {
      if (is.null(status)) status <- "completed"
      DBI::dbExecute(self$connection, "UPDATE runs SET status=?,finished=? WHERE run_id=?",
                     params = list(status, private$tools$now(), self$run_id))
      invisible(status)
    },
    clear_platform = function(platform) {
      DBI::dbWithTransaction(self$connection, {
        for (table in c("evidences", "artifacts", "repositories")) {
          DBI::dbExecute(self$connection, paste0("DELETE FROM ", table, " WHERE platform=?"),
                         params = list(platform))
        }
      })
    },
    repository = function(record) {
      DBI::dbExecute(self$connection, paste(
        "INSERT OR REPLACE INTO repositories(repo_key,platform,repo_type,identifier,status,reason,payload,run_id)",
        "VALUES(?,?,?,?,?,?,?,?)"), params = list(record$key, record$platform, record$type,
        record$id, record$status, record$reason, private$tools$json(record), self$run_id))
      for (evidence in record$ai$signals) {
        evidence$unit_key <- record$key
        evidence$artifact_key <- record$key
        self$evidence(evidence, record$platform)
      }
      invisible(record)
    },
    artifact = function(record) {
      DBI::dbExecute(self$connection, paste(
        "INSERT OR IGNORE INTO artifacts(artifact_key,unit_key,repo_key,platform,kind,created,text,url,payload,run_id)",
        "VALUES(?,?,?,?,?,?,?,?,?,?)"), params = list(record$key, record$unit_key, record$repo_key,
        record$platform, record$kind, record$created, record$text, record$url,
        private$tools$json(record), self$run_id))
      invisible(record)
    },
    evidence = function(record, platform) {
      id <- private$tools$hash(private$tools$json(record))
      DBI::dbExecute(self$connection, paste(
        "INSERT OR IGNORE INTO evidences(evidence_id,unit_key,artifact_key,platform,kind,label,term,vocabulary,payload,run_id)",
        "VALUES(?,?,?,?,?,?,?,?,?,?)"), params = list(id, record$unit_key, record$artifact_key,
        platform, record$kind, record$label, record$term, record$vocabulary,
        private$tools$json(record), self$run_id))
      invisible(id)
    },
    problem = function(code, resource, detail, resolved = FALSE) {
      recovery_key <- private$problem_recovery_key(code, resource, detail, resolved)
      private$save_problem(code, resource, detail, resolved, recovery_key)
      invisible(recovery_key)
    },
    with_recovery_item = function(kind, item_key, payload, action) {
      previous <- private$recovery_context
      private$recovery_context <- list(kind = kind, key = item_key, payload = payload)
      on.exit(private$recovery_context <- previous, add = TRUE)
      action()
    },
    pending_recovery_items = function(run_id = self$run_id) {
      if (is.null(run_id) || !DBI::dbExistsTable(self$connection, "recovery_items")) {
        return(data.frame(item_key = character(), kind = character(), payload = character(), stringsAsFactors = FALSE))
      }
      self$query(paste("SELECT item_key,kind,payload FROM recovery_items",
        "WHERE run_id=? AND status='pending' ORDER BY item_key"), list(run_id))
    },
    recovery_item_count = function(run_id = self$run_id) {
      if (is.null(run_id) || !DBI::dbExistsTable(self$connection, "recovery_items")) return(0L)
      as.integer(self$query("SELECT COUNT(*) n FROM recovery_items WHERE run_id=? AND status='pending'",
        list(run_id))$n[[1L]])
    },
    resolve_recovery_item = function(item_key, run_id = self$run_id) {
      DBI::dbExecute(self$connection,
        "UPDATE recovery_items SET status='resolved',updated=? WHERE run_id=? AND item_key=?",
        params = list(private$tools$now(), run_id, item_key))
      DBI::dbExecute(self$connection,
        "UPDATE problems SET resolved=1 WHERE run_id=? AND recovery_key=? AND resolved=0",
        params = list(run_id, item_key))
      invisible(TRUE)
    },
    keep_recovery_item_pending = function(item_key, run_id = self$run_id) {
      DBI::dbExecute(self$connection,
        "UPDATE recovery_items SET status='pending',updated=? WHERE run_id=? AND item_key=?",
        params = list(private$tools$now(), run_id, item_key))
      invisible(TRUE)
    },
    begin_recovery_attempt = function(item_key, pass, run_id = self$run_id) {
      DBI::dbExecute(self$connection,
        "INSERT INTO recovery_attempts(run_id,item_key,pass,started,outcome) VALUES(?,?,?,?,?)",
        params = list(run_id, item_key, as.integer(pass), private$tools$now(), "running"))
      as.integer(DBI::dbGetQuery(self$connection, "SELECT last_insert_rowid() id")$id[[1L]])
    },
    finish_recovery_attempt = function(attempt_id, outcome, run_id = self$run_id) {
      DBI::dbExecute(self$connection,
        "UPDATE recovery_attempts SET finished=?,outcome=? WHERE attempt_id=? AND run_id=?",
        params = list(private$tools$now(), outcome, attempt_id, run_id))
      invisible(outcome)
    },
    recovery_summary = function(run_id = self$run_id) {
      if (is.null(run_id) || !DBI::dbExistsTable(self$connection, "recovery_summaries")) return(data.frame())
      self$query("SELECT * FROM recovery_summaries WHERE run_id=?", list(run_id))
    },
    save_recovery_summary = function(summary) {
      columns <- c("run_id", "initial_pending", "initial_diagnostics", "pass1_attempted", "pass1_resolved",
        "pass1_pending", "pass1_created", "pass2_attempted", "pass2_resolved", "pass2_created",
        "final_pending", "final_diagnostics", "budget_seconds", "elapsed_seconds", "started", "finished")
      values <- lapply(columns, function(column) summary[[column]])
      names(values) <- columns
      DBI::dbExecute(self$connection, paste0("INSERT OR REPLACE INTO recovery_summaries(",
        paste(columns, collapse = ","), ") VALUES(", paste(rep("?", length(columns)), collapse = ","), ")"),
        params = unname(values))
      invisible(summary)
    },
    problem_count = function(run_id = self$run_id, unresolved_only = FALSE) {
      if (is.null(run_id)) return(0L)
      filter <- if (unresolved_only) " AND resolved=0" else ""
      as.integer(self$query(paste0("SELECT COUNT(*) n FROM problems WHERE run_id=?", filter), list(run_id))$n[[1L]])
    },
    unavailable = function(resource, reason) {
      DBI::dbExecute(self$connection,
        "INSERT INTO unavailable(run_id,resource,reason,created) VALUES(?,?,?,?)",
        params = list(self$run_id, resource, reason, private$tools$now()))
      invisible(FALSE)
    },
    response = function(url, result, attempt) {
      raw <- result$body
      if (is.character(raw)) raw <- charToRaw(enc2utf8(raw))
      sha <- private$tools$hash(raw)
      root <- private$config$settings$paths$raw
      if (private$pilot) root <- file.path(root, "pilot")
      relative <- file.path(root, self$run_id, paste0(sha, ".body"))
      path <- private$config$path(relative)
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      if (!file.exists(path)) writeBin(raw, path)
      headers <- result$headers
      headers <- headers[!tolower(names(headers)) %in% c("set-cookie", "authorization", "cookie")]
      DBI::dbExecute(self$connection, paste(
        "INSERT INTO responses(run_id,url,status,sha256,path,headers,attempt,created)",
        "VALUES(?,?,?,?,?,?,?,?)"), params = list(self$run_id, url, result$status, sha, relative,
        private$tools$json(headers), attempt, private$tools$now()))
      invisible(sha)
    },
    attempt = function(url, number, status, detail = "") {
      DBI::dbExecute(self$connection,
        "INSERT INTO attempts(run_id,url,number,status,detail,created) VALUES(?,?,?,?,?,?)",
        params = list(self$run_id, url, number, status, detail, private$tools$now()))
    },
    counts = function() {
      pending_filter <- private$pending_issue_filter()
      list(catalogued = self$query("SELECT platform,repo_type,COUNT(*) n FROM repositories GROUP BY platform,repo_type"),
        eligible = self$query("SELECT platform,repo_type,COUNT(*) n FROM repositories WHERE status='eligible' GROUP BY platform,repo_type"),
        artifacts = self$query("SELECT platform,kind,COUNT(*) n FROM artifacts GROUP BY platform,kind"),
        repositories_with_evidence = self$query(paste(
          "SELECT r.platform,r.repo_type,COUNT(DISTINCT r.repo_key) n FROM evidences e",
          "JOIN artifacts a ON a.artifact_key=e.unit_key JOIN repositories r ON r.repo_key=a.repo_key",
          "WHERE e.kind='legal' AND r.status='eligible'", pending_filter, "GROUP BY r.platform,r.repo_type")),
        legal_discussions = self$query(paste(
          "SELECT e.platform,r.repo_type,COUNT(DISTINCT e.unit_key) n FROM evidences e",
          "JOIN artifacts a ON a.artifact_key=e.unit_key JOIN repositories r ON r.repo_key=a.repo_key",
          "WHERE e.kind='legal' AND r.status='eligible'", pending_filter, "GROUP BY e.platform,r.repo_type")))
    }
  ),
  private = list(
    config = NULL, tools = NULL, pilot = FALSE, recover = FALSE, readonly = FALSE, cache = NULL,
    recovery_context = NULL,
    ensure_recovery_item = function(kind, item_key, payload) {
      DBI::dbExecute(self$connection, paste(
        "INSERT OR IGNORE INTO recovery_items(run_id,item_key,kind,payload,status,created,updated)",
        "VALUES(?,?,?,?,?,?,?)"), params = list(self$run_id, item_key, kind,
          private$tools$json(payload), "pending", private$tools$now(), private$tools$now()))
      invisible(item_key)
    },
    pending_issue_filter = function() {
      if (!DBI::dbExistsTable(self$connection, "recovery_items")) return("")
      paste("AND NOT EXISTS (SELECT 1 FROM recovery_items ri",
        "WHERE ri.run_id=a.run_id AND ri.item_key=a.artifact_key",
        "AND ri.kind='issue' AND ri.status='pending')")
    },
    problem_recovery_key = function(code, resource, detail, resolved) {
      if (isTRUE(resolved) || is.null(self$run_id) || private$pilot) return(NULL)
      run <- self$query("SELECT platform FROM runs WHERE run_id=?", list(self$run_id))
      if (nrow(run) != 1L || !identical(run$platform[[1L]], "github")) return(NULL)
      context <- private$recovery_context
      if (!is.null(context)) {
        item_key <- context$key
        private$ensure_recovery_item(context$kind, item_key, context$payload)
      } else {
        identity <- as.character(resource)
        if (!grepl("^https://api\\.github\\.com/", identity)) identity <- paste(code, identity, sep = "|")
        item_key <- paste0("unmapped:", private$tools$hash(enc2utf8(identity)))
        private$ensure_recovery_item("unmapped", item_key,
          list(code = code, resource = identity, detail = as.character(detail)))
      }
      DBI::dbExecute(self$connection,
        "UPDATE recovery_items SET status='pending',updated=? WHERE run_id=? AND item_key=?",
        params = list(private$tools$now(), self$run_id, item_key))
      item_key
    },
    save_problem = function(code, resource, detail, resolved, recovery_key) {
      if (!is.null(recovery_key)) {
        existing <- self$query(paste("SELECT problem_id FROM problems WHERE run_id=? AND recovery_key=?",
          "AND code=? AND resource=? LIMIT 1"), list(self$run_id, recovery_key, code, resource))
        if (nrow(existing) == 1L) {
          DBI::dbExecute(self$connection,
            "UPDATE problems SET detail=?,resolved=?,created=? WHERE problem_id=?",
            params = list(as.character(detail), as.integer(resolved), private$tools$now(), existing$problem_id[[1L]]))
          return(invisible(existing$problem_id[[1L]]))
        }
      }
      DBI::dbExecute(self$connection,
        "INSERT INTO problems(run_id,code,resource,detail,resolved,created,recovery_key) VALUES(?,?,?,?,?,?,?)",
        params = list(self$run_id, code, resource, as.character(detail), as.integer(resolved),
                      private$tools$now(), if (is.null(recovery_key)) NA_character_ else recovery_key))
      invisible(TRUE)
    },
    recover_responses = function(platform) {
      private$cache <- new.env(parent = emptyenv())
      if (!private$recover || private$pilot) return(invisible(NULL))
      target <- private$config$database_path(platform)
      pattern <- paste0("^\\.staging-", platform, "-.*\\.sqlite$")
      files <- list.files(dirname(target), pattern, all.files = TRUE, full.names = TRUE)
      files <- files[files != self$path]
      dates <- file.info(files)$mtime
      if (file.exists(target)) files <- files[!is.na(dates) & dates >= file.info(target)$mtime]
      files <- files[order(file.info(files)$mtime, decreasing = TRUE)]
      for (file in files) {
        rows <- tryCatch(private$recovery_rows(file, platform), error = function(error) NULL)
        if (is.null(rows)) next
        private$cache <- list2env(rows, parent = emptyenv(), hash = TRUE)
        break
      }
      invisible(NULL)
    },
    recovery_rows = function(path, platform) {
      connection <- DBI::dbConnect(RSQLite::SQLite(), path, flags = RSQLite::SQLITE_RO)
      on.exit(DBI::dbDisconnect(connection), add = TRUE)
      run <- DBI::dbGetQuery(connection, paste(
        "SELECT run_id,status FROM runs WHERE platform=? AND pilot=0 AND config_hash=?",
        "ORDER BY rowid DESC LIMIT 1"), params = list(platform, private$config$fingerprint))
      if (nrow(run) != 1L || !run$status %in% c("running", "failed")) return(NULL)
      rows <- DBI::dbGetQuery(connection, paste(
        "SELECT url,status,sha256,path,headers FROM responses WHERE run_id=? ORDER BY id DESC"),
        params = list(run$run_id))
      rows <- rows[!duplicated(rows$url), , drop = FALSE]
      bad <- DBI::dbGetQuery(connection, "SELECT resource FROM problems WHERE run_id=? AND resolved=0",
        params = list(run$run_id))$resource
      invalid <- vapply(rows$url, function(url) any(url == bad | startsWith(url, paste0(bad, "/"))), logical(1))
      rows <- rows[rows$status >= 200L & rows$status < 300L & !invalid, , drop = FALSE]
      output <- lapply(seq_len(nrow(rows)), function(index) as.list(rows[index, , drop = FALSE]))
      names(output) <- rows$url
      output
    },
    schema = function() {
      statements <- c(
        "CREATE TABLE IF NOT EXISTS runs(run_id TEXT PRIMARY KEY,platform TEXT,pilot INTEGER,status TEXT,cutoff TEXT,version TEXT,config_hash TEXT,started TEXT,finished TEXT)",
        "CREATE TABLE IF NOT EXISTS repositories(repo_key TEXT PRIMARY KEY,platform TEXT,repo_type TEXT,identifier TEXT,status TEXT,reason TEXT,payload TEXT,run_id TEXT)",
        "CREATE TABLE IF NOT EXISTS artifacts(artifact_key TEXT PRIMARY KEY,unit_key TEXT,repo_key TEXT,platform TEXT,kind TEXT,created TEXT,text TEXT,url TEXT,payload TEXT,run_id TEXT)",
        "CREATE TABLE IF NOT EXISTS evidences(evidence_id TEXT PRIMARY KEY,unit_key TEXT,artifact_key TEXT,platform TEXT,kind TEXT,label TEXT,term TEXT,vocabulary TEXT,payload TEXT,run_id TEXT)",
        "CREATE TABLE IF NOT EXISTS problems(problem_id INTEGER PRIMARY KEY,run_id TEXT,code TEXT,resource TEXT,detail TEXT,resolved INTEGER,created TEXT,recovery_key TEXT)",
        "CREATE TABLE IF NOT EXISTS unavailable(id INTEGER PRIMARY KEY,run_id TEXT,resource TEXT,reason TEXT,created TEXT)",
        "CREATE TABLE IF NOT EXISTS responses(id INTEGER PRIMARY KEY,run_id TEXT,url TEXT,status INTEGER,sha256 TEXT,path TEXT,headers TEXT,attempt INTEGER,created TEXT)",
        "CREATE TABLE IF NOT EXISTS attempts(id INTEGER PRIMARY KEY,run_id TEXT,url TEXT,number INTEGER,status INTEGER,detail TEXT,created TEXT)",
        "CREATE TABLE IF NOT EXISTS recovery_items(run_id TEXT,item_key TEXT,kind TEXT,payload TEXT,status TEXT,created TEXT,updated TEXT,PRIMARY KEY(run_id,item_key))",
        "CREATE TABLE IF NOT EXISTS recovery_attempts(attempt_id INTEGER PRIMARY KEY,run_id TEXT,item_key TEXT,pass INTEGER,started TEXT,finished TEXT,outcome TEXT)",
        paste0("CREATE TABLE IF NOT EXISTS recovery_summaries(run_id TEXT PRIMARY KEY,initial_pending INTEGER,initial_diagnostics INTEGER,",
          "pass1_attempted INTEGER,pass1_resolved INTEGER,pass1_pending INTEGER,pass1_created INTEGER,",
          "pass2_attempted INTEGER,pass2_resolved INTEGER,pass2_created INTEGER,final_pending INTEGER,",
          "final_diagnostics INTEGER,budget_seconds REAL,elapsed_seconds REAL,started TEXT,finished TEXT)"),
        "CREATE INDEX IF NOT EXISTS artifacts_unit ON artifacts(unit_key)",
        "CREATE INDEX IF NOT EXISTS evidences_unit ON evidences(unit_key,kind)",
        "CREATE INDEX IF NOT EXISTS recovery_pending ON recovery_items(run_id,status)")
      for (sql in statements) DBI::dbExecute(self$connection, sql)
      if (!"recovery_key" %in% DBI::dbListFields(self$connection, "problems")) {
        DBI::dbExecute(self$connection, "ALTER TABLE problems ADD COLUMN recovery_key TEXT")
      }
      if (!"budget_seconds" %in% DBI::dbListFields(self$connection, "recovery_summaries")) {
        DBI::dbExecute(self$connection, "ALTER TABLE recovery_summaries ADD COLUMN budget_seconds REAL")
      }
      DBI::dbExecute(self$connection, "CREATE INDEX IF NOT EXISTS recovery_problem ON problems(run_id,recovery_key,resolved)")
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
