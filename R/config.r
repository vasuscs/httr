#' Set curl options.
#'
#' Generally you should only need to use this function to set CURL options
#' directly if there isn't already a helpful wrapper function, like
#' \code{\link{set_cookies}}, \code{\link{add_headers}} or
#' \code{\link{authenticate}}. To use this function effectively requires
#' some knowledge of CURL, and CURL options. Use \code{\link{httr_options}} to
#' see a complete list of available options. To see the libcurl documentation
#' for a given option, use \code{\link{curl_docs}}.
#'
#' Unlike Curl (and RCurl), all configuration options are per request, not
#' per handle.
#'
#' @seealso \code{\link{set_config}} to set global config defaults, and
#'  \code{\link{with_config}} to temporarily run code with set options.
#' @family config
#' @family ways to set configuration
#' @seealso All known available options are listed in \code{\link{httr_options}}
#' @param ... named Curl options.
#' @export
#' @examples
#' # There are a number of ways to modify the configuration of a request
#' # * you can add directly to a request
#' HEAD("https://www.google.com", verbose())
#'
#' # * you can wrap with with_config()
#' with_config(verbose(), HEAD("https://www.google.com"))
#'
#' # * you can set global with set_config()
#' old <- set_config(verbose())
#' HEAD("https://www.google.com")
#' # and re-establish the previous settings with
#' set_config(old, override = TRUE)
#' HEAD("https://www.google.com")
#' # or
#' reset_config()
#' HEAD("https://www.google.com")
#'
#' # If available, you should use a friendly httr wrapper over RCurl
#' # options. But you can pass Curl options (as listed in httr_options())
#' # in config
#' HEAD("https://www.google.com/", config(verbose = TRUE))
config <- function(...) {
  request(options = list(...))
}

is.config <- function(x) inherits(x, "config")

#' List available options.
#'
#' This function lists all available options for \code{\link{config}()}.
#' It provides both the short R name which you use with httr, and the longer
#' Curl name, which is useful when searching the documentation. \code{curl_doc}
#' opens a link to the libcurl documentation for an option in your browser.
#'
#' RCurl and httr use slightly different names to libcurl: the initial
#' \code{CURLOPT_} is removed, all underscores are converted to periods and
#' the option is given in lower case.  Thus "CURLOPT_SSLENGINE_DEFAULT"
#' becomes "sslengine.default".
#'
#' @param x An option name (either short or full).
#' @param matches If not missing, this restricts the output so that either
#'   the httr or curl option matches this regular expression.
#' @return A data frame with three columns:
#' \item{httr}{The short name used in httr}
#' \item{libcurl}{The full name used by libcurl}
#' \item{type}{The type of R object that the option accepts}
#' @export
#' @examples
#' httr_options()
#' httr_options("post")
#'
#' # Use curl_docs to read the curl documentation for each option.
#' # You can use either the httr or curl option name.
#' curl_docs("userpwd")
#' curl_docs("CURLOPT_USERPWD")
httr_options <- function(matches) {

  constants <- curl::curl_options()
  constants <- constants[order(names(constants))]

  rcurl <- tolower(names(constants))

  opts <- data.frame(
    httr = rcurl,
    libcurl = translate_curl(rcurl),
    type = curl_option_types(constants),
    stringsAsFactors = FALSE
  )

  if (!missing(matches)) {
    sel <- grepl(matches, opts$httr, ignore.case = TRUE) |
      grepl(matches, opts$libcurl, ignore.case = TRUE)
    opts <- opts[sel, , drop = FALSE]
  }

  opts
}

curl_option_types <- function(opts = curl::curl_options()) {
  type_name <- c("integer", "string", "function", "number")
  type <- floor(opts / 10000)

  type_name[type + 1]
}

#' @export
print.opts_list <- function(x, ...) {
  cat(paste0(format(names(x)), ": ", x, collapse = "\n"), "\n", sep = "")
}

translate_curl <- function(x) {
  paste0("CURLOPT_", gsub(".", "_", toupper(x), fixed = TRUE))
}

#' @export
#' @rdname httr_options
curl_docs <- function(x) {
  stopifnot(is.character(x), length(x) == 1)

  opts <- httr_options()
  if (x %in% opts$httr) {
    x <- opts$libcurl[match(x, opts$httr)]
  }
  if (!(x %in% opts$libcurl)) {
    stop(x, " is not a known curl option", call. = FALSE)
  }

  url <- paste0("http://curl.haxx.se/libcurl/c/", x, ".html")
  BROWSE(url)
}

#' @export
c.config <- function(...) {
  Reduce(modify_config, list(...))
}

#' @export
print.config <- function(x, ...) {
  cat("Config: \n")
  str(unclass(x), give.head = FALSE)
}

# A version of modifyList that works with config files, and merges
# http header
modify_config <- function(x, val) {
  overwrite <- setdiff(names(val), "httpheader")
  x[overwrite] <- val[overwrite]

  headers <- c(x$httpheader, val$httpheader)
  x$httpheader <- add_headers(.headers = headers)$httpheader

  x
}

make_config <- function(x, ...) {
  configs <- c(list(x), unnamed(list(...)))

  structure(Reduce(modify_config, configs), class = "config")
}

default_ua <- function() {
  versions <- c(
    libcurl = curl::curl_version()$version,
    `r-curl` = as.character(packageVersion("curl")),
    httr = as.character(packageVersion("httr"))
  )
  paste0(names(versions), "/", versions, collapse = " ")
}

#' Set (and reset) global httr configuration.
#'
#' @param config Settings as generated by \code{\link{add_headers}},
#'   \code{\link{set_cookies}} or \code{\link{authenticate}}.
#' @param override if \code{TRUE}, ignore existing settings, if \code{FALSE},
#'   combine new config with old.
#' @return invisibility, the old global config.
#' @family ways to set configuration
#' @export
#' @examples
#' GET("http://google.com")
#' set_config(verbose())
#' GET("http://google.com")
#' reset_config()
#' GET("http://google.com")
set_config <- function(config, override = FALSE) {
  stopifnot(is.config(config))

  old <- getOption("httr_config") %||% config()
  if (!override) config <- c(old, config)
  options(httr_config = config)
  invisible(old)
}

#' @export
#' @rdname set_config
reset_config <- function() set_config(config(), TRUE)

#' Execute code with configuration set.
#'
#' @family ways to set configuration
#' @inheritParams set_config
#' @param expr code to execute under specified configuration
#' @export
#' @examples
#' with_config(verbose(), {
#'   GET("http://had.co.nz")
#'   GET("http://google.com")
#' })
#'
#' # Or even easier:
#' with_verbose(GET("http://google.com"))
with_config <- function(config = config(), expr, override = FALSE) {
  stopifnot(is.config(config))

  old <- set_config(config, override)
  on.exit(set_config(old, override = TRUE))
  force(expr)
}

#' @export
#' @param ... Other arguments passed on to \code{\link{verbose}}
#' @rdname with_config
with_verbose <- function(expr, ...) {
  with_config(verbose(...), expr)
}
