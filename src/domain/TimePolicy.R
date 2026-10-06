TimePolicy <- R6::R6Class("TimePolicy",
  public = list(
    end = NULL,
    initialize = function(cutoff) {
      self$end <- self$parse(cutoff) + 86400
      if (is.na(self$end)) stop("Corte inválido")
    },
    parse = function(value) {
      invalid <- as.POSIXct(NA, tz = "UTC")
      if (is.null(value) || length(value) != 1L || is.na(value)) return(invalid)
      value <- as.character(value)
      pattern <- "^\\d{4}-\\d{2}-\\d{2}(T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:?\\d{2}))?$"
      if (!grepl(pattern, value, perl = TRUE)) return(invalid)
      core <- substr(value, 1L, 19L)
      if (nchar(value) == 10L) core <- paste0(value, "T00:00:00")
      parsed <- as.POSIXct(strptime(core, "%Y-%m-%dT%H:%M:%S", tz = "UTC"))
      if (is.na(parsed) || format(parsed, "%Y-%m-%dT%H:%M:%S", tz = "UTC") != core) return(invalid)
      parsed + private$fraction(value) - private$offset(value)
    },
    eligible = function(created, start = "1970-01-01") {
      date <- self$parse(created)
      !is.na(date) && date >= self$parse(start) && date < self$end
    },
    stamp = function(date) format(date, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  ),
  private = list(
    fraction = function(value) {
      match <- regmatches(value, regexpr("\\.\\d+", value, perl = TRUE))
      if (!length(match) || !nzchar(match)) return(0)
      as.numeric(match)
    },
    offset = function(value) {
      suffix <- regmatches(value, regexpr("[+-]\\d{2}:?\\d{2}$", value, perl = TRUE))
      if (!length(suffix) || !nzchar(suffix)) return(0)
      compact <- gsub(":", "", suffix, fixed = TRUE)
      hours <- as.numeric(substr(compact, 2, 3))
      minutes <- as.numeric(substr(compact, 4, 5))
      if (hours > 23 || minutes > 59) return(NA_real_)
      sign <- if (substr(compact, 1, 1) == "-") -1 else 1
      sign * (hours * 3600 + minutes * 60)
    }
  ), lock_objects = TRUE, lock_class = TRUE, cloneable = FALSE)
