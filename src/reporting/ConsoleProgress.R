ConsoleProgress <- R6::R6Class("ConsoleProgress",
  public = list(
    enabled = TRUE,
    initialize = function(clock = NULL, write = NULL, terminal = isatty(stdout()), enabled = TRUE) {
      private$clock <- if (is.null(clock)) function() as.numeric(Sys.time()) else clock
      private$write <- if (is.null(write)) function(text) { cat(text); flush.console() } else write
      private$terminal <- isTRUE(terminal)
      self$enabled <- isTRUE(enabled)
    },
    begin = function(label, steps, started = NULL) {
      now <- private$clock()
      private$started <- if (is.null(started)) now else started
      private$last_report <- now
      private$steps <- steps
      private$index <- 0L
      private$active <- TRUE
      private$stage_started <- NULL
      private$scope_started <- NULL
      private$stage_label <- ""
      private$context <- ""
      private$counts <- NULL
      self$event(label)
    },
    stage = function(label, counts = NULL) {
      private$index <- private$index + 1L
      private$stage_label <- label
      private$stage_started <- private$clock()
      private$scope_started <- NULL
      private$context <- ""
      private$counts <- counts
      self$event(sprintf("\n[%d/%d] %s", private$index, private$steps, label))
      self$activity("Iniciando")
    },
    scope = function(label, context = label, timer = "Busca") {
      private$scope_started <- private$clock()
      private$timer <- timer
      private$context <- context
      self$event(label)
    },
    activity = function(label, context = NULL) {
      private$activity_label <- label
      if (!is.null(context)) private$context <- context
      self$tick()
    },
    tick = function() {
      if (!self$enabled || !private$active) return(invisible(TRUE))
      now <- private$clock()
      if (now - private$last_report >= 300) self$report()
      if (private$terminal && now - private$last_frame >= 0.2) private$frame(now)
      invisible(TRUE)
    },
    report = function(label = "Progresso", counts = TRUE) {
      if (!self$enabled || !private$active) return(invisible(NULL))
      now <- private$clock()
      fields <- c(label, if (label == "Progresso") private$description(), private$timing(now))
      text <- paste(fields, collapse = " | ")
      if (counts && !is.null(private$counts)) text <- paste0(text, "\n  ", private$counts())
      self$event(text)
      private$last_report <- now
    },
    event = function(text) {
      if (!self$enabled) return(invisible(NULL))
      self$clear()
      private$write(paste0(text, "\n"))
    },
    clear = function() {
      if (private$visible) private$write("\r\033[2K")
      private$visible <- FALSE
      private$last_frame <- -Inf
    },
    finish = function(label) {
      private$active <- FALSE
      self$event(paste0(label, " | Total: ", private$format_duration(private$clock() - private$started)))
    },
    wait = function(seconds, sleep, clock, reason = NULL) {
      until <- clock() + max(0, seconds)
      activity <- private$activity_label
      while ((remaining <- until - clock()) > 0) {
        if (!is.null(reason)) self$activity(paste(reason, "| faltam", private$format_duration(remaining)))
        interval <- if (!self$enabled) remaining else if (private$terminal) 0.2 else 300
        sleep(min(remaining, interval))
        self$tick()
      }
      private$activity_label <- activity
    },
    duration = function(seconds) private$format_duration(seconds)
  ),
  private = list(
    clock = NULL, write = NULL, terminal = FALSE, active = FALSE, visible = FALSE,
    started = NULL, stage_started = NULL, scope_started = NULL, steps = 0L, index = 0L,
    stage_label = "", context = "", activity_label = "", timer = "Busca", counts = NULL,
    last_report = 0, last_frame = -Inf, frame_index = 0L,
    format_duration = function(seconds) {
      seconds <- floor(max(0, seconds))
      days <- seconds %/% 86400
      text <- sprintf("%02d:%02d:%02d", (seconds %% 86400) %/% 3600,
        (seconds %% 3600) %/% 60, seconds %% 60)
      if (days > 0) paste0(days, "d ", text) else text
    },
    description = function() {
      fields <- c(private$stage_label, private$context, private$activity_label)
      paste(fields[nzchar(fields)], collapse = " | ")
    },
    timing = function(now) {
      total <- paste0("Total: ", private$format_duration(now - private$started))
      if (is.null(private$stage_started)) return(total)
      start <- if (is.null(private$scope_started)) private$stage_started else private$scope_started
      label <- if (is.null(private$scope_started)) "Etapa" else private$timer
      paste0(label, ": ", private$format_duration(now - start), " | ", total)
    },
    frame = function(now) {
      frames <- c("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
      private$frame_index <- private$frame_index %% length(frames) + 1L
      tail <- paste0(" | ", private$timing(now))
      width <- max(1L, getOption("width", 80L) - nchar(tail, type = "width") - 3L)
      available <- min(22L, max(0L, width - nchar(private$activity_label, type = "width") - 3L))
      context <- substr(private$context, 1L, available)
      if (nchar(private$context, type = "width") > available && available >= 4L) {
        context <- paste0(substr(context, 1L, available - 3L), "...")
      }
      fields <- c(context, private$activity_label)
      label <- paste(fields[nzchar(fields)], collapse = " | ")
      text <- paste0(frames[[private$frame_index]], " ", substr(label, 1L, width), tail)
      private$write(paste0("\r\033[2K", text))
      private$visible <- TRUE
      private$last_frame <- now
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
