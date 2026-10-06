FixtureFactory <- R6::R6Class("FixtureFactory",
  public = list(
    initialize = function(config) private$config <- config,
    create = function() {
      config <- ProjectConfig$new(private$config$root)
      config$root <- tempfile("privacy-test-")
      dir.create(config$root)
      store <- AuditStore$new(file.path(config$root, "test.sqlite"), config)
      list(config = config, store = store, cleanup = function() {
        store$close()
        unlink(config$root, recursive = TRUE)
      })
    },
    response = function(data = list(), status = 200L, headers = list(), text = NULL) {
      if (is.null(text)) {
        text <- ProtocolTools$new()$json(data)
        headers[["content-type"]] <- "application/json"
      }
      list(status = status, headers = headers, body = charToRaw(enc2utf8(text)))
    },
    http = function(fixture, platform, transport) {
      now <- 0
      HttpClient$new(platform, fixture$config, fixture$store, transport,
        clock = function() now, sleep = function(seconds) { now <<- now + seconds })
    }
  ), private = list(config = NULL),
  lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
