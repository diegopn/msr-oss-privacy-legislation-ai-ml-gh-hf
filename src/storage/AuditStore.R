AuditStore <- R6::R6Class("AuditStore",
  public = list(
    connection = NULL, run_id = NULL, path = NULL,
    initialize = function(path, config, recover = FALSE) {
      self$path <- path
      private$config <- config
      private$tools <- ProtocolTools$new()
      private$recover <- recover
      private$cache <- new.env(parent = emptyenv())
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      self$connection <- DBI::dbConnect(RSQLite::SQLite(), path)
      DBI::dbExecute(self$connection, "PRAGMA foreign_keys = ON")
      DBI::dbExecute(self$connection, "PRAGMA busy_timeout = 5000")
      private$schema()
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
      DBI::dbExecute(self$connection,
        "INSERT INTO problems(run_id,code,resource,detail,resolved,created) VALUES(?,?,?,?,?,?)",
        params = list(self$run_id, code, resource, as.character(detail), as.integer(resolved),
                      private$tools$now()))
      invisible(FALSE)
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
      list(catalogued = self$query("SELECT platform,repo_type,COUNT(*) n FROM repositories GROUP BY platform,repo_type"),
        eligible = self$query("SELECT platform,repo_type,COUNT(*) n FROM repositories WHERE status='eligible' GROUP BY platform,repo_type"),
        artifacts = self$query("SELECT platform,kind,COUNT(*) n FROM artifacts GROUP BY platform,kind"),
        legal_discussions = self$query(paste(
          "SELECT e.platform,r.repo_type,COUNT(DISTINCT e.unit_key) n FROM evidences e",
          "JOIN artifacts a ON a.artifact_key=e.unit_key JOIN repositories r ON r.repo_key=a.repo_key",
          "WHERE e.kind='legal' AND r.status='eligible' GROUP BY e.platform,r.repo_type")))
    }
  ),
  private = list(
    config = NULL, tools = NULL, pilot = FALSE, recover = FALSE, cache = NULL,
    recover_responses = function(platform) {
      private$cache <- new.env(parent = emptyenv())
      if (!private$recover || private$pilot) return(invisible(NULL))
      target <- private$config$path(private$config$settings$paths$database)
      files <- list.files(dirname(target), "^\\.staging-.*\\.sqlite$", all.files = TRUE, full.names = TRUE)
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
        "CREATE TABLE IF NOT EXISTS problems(problem_id INTEGER PRIMARY KEY,run_id TEXT,code TEXT,resource TEXT,detail TEXT,resolved INTEGER,created TEXT)",
        "CREATE TABLE IF NOT EXISTS unavailable(id INTEGER PRIMARY KEY,run_id TEXT,resource TEXT,reason TEXT,created TEXT)",
        "CREATE TABLE IF NOT EXISTS responses(id INTEGER PRIMARY KEY,run_id TEXT,url TEXT,status INTEGER,sha256 TEXT,path TEXT,headers TEXT,attempt INTEGER,created TEXT)",
        "CREATE TABLE IF NOT EXISTS attempts(id INTEGER PRIMARY KEY,run_id TEXT,url TEXT,number INTEGER,status INTEGER,detail TEXT,created TEXT)",
        "CREATE INDEX IF NOT EXISTS artifacts_unit ON artifacts(unit_key)",
        "CREATE INDEX IF NOT EXISTS evidences_unit ON evidences(unit_key,kind)")
      for (sql in statements) DBI::dbExecute(self$connection, sql)
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
