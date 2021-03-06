#' Create a new layer
#'
#' @export
#' @inheritParams geom_point
#' @param geom,stat,position Geom, stat and position adjustment to use in
#'   this layer. Can either be the name of a ggproto object, or the object
#'   itself.
#' @param params Additional parameters to the \code{geom} and \code{stat}.
#' @param subset DEPRECATED. An older way of subsetting the dataset used in a
#'   layer.
#' @examples
#' # geom calls are just a short cut for layer
#' ggplot(mpg, aes(displ, hwy)) + geom_point()
#' # shortcut for
#' ggplot(mpg, aes(displ, hwy)) +
#'   layer(geom = "point", stat = "identity", position = "identity")
layer <- function(geom = NULL, stat = NULL,
                  data = NULL, mapping = NULL,
                  position = NULL, params = list(),
                  inherit.aes = TRUE, subset = NULL, show.legend = NA) {
  if (is.null(geom))
    stop("Attempted to create layer with no geom.", call. = FALSE)
  if (is.null(stat))
    stop("Attempted to create layer with no stat.", call. = FALSE)
  if (is.null(position))
    stop("Attempted to create layer with no position.", call. = FALSE)

  # Handle show_guide/show.legend
  if (!is.null(params$show_guide)) {
    warning("`show_guide` has been deprecated. Please use `show.legend` instead.",
      call. = FALSE)
    show.legend <- params$show_guide
    params$show_guide <- NULL
  }
  if (!is.logical(show.legend) || length(show.legend) != 1) {
    warning("`show.legend` must be a logical vector of length 1.", call. = FALSE)
    show.legend <- FALSE
  }

  data <- fortify(data)
  if (!is.null(mapping) && !inherits(mapping, "uneval")) {
    stop("Mapping must be created by `aes()` or `aes_()`", call. = FALSE)
  }

  if (is.character(geom))
    geom <- find_subclass("Geom", geom)
  if (is.character(stat))
    stat <- find_subclass("Stat", stat)
  if (is.character(position))
    position <- find_subclass("Position", position)

  # Split up params between aesthetics, geom, and stat
  params <- rename_aes(params)
  aes_params  <- params[intersect(names(params), geom$aesthetics())]
  geom_params <- params[intersect(names(params), geom$parameters())]
  stat_params <- params[intersect(names(params), stat$parameters())]

  all <- c(geom$parameters(), stat$parameters(), geom$aesthetics())
  extra <- setdiff(names(params), all)
  if (length(extra) > 0) {
    stop("Unknown parameters: ", paste(extra, collapse = ", "), call. = FALSE)
  }

  ggproto("LayerInstance", Layer,
    geom = geom,
    geom_params = geom_params,
    stat = stat,
    stat_params = stat_params,
    data = data,
    mapping = mapping,
    aes_params = aes_params,
    subset = subset,
    position = position,
    inherit.aes = inherit.aes,
    show.legend = show.legend
  )
}

Layer <- ggproto("Layer", NULL,
  geom = NULL,
  geom_params = NULL,
  stat = NULL,
  stat_params = NULL,
  data = NULL,
  aes_params = NULL,
  mapping = NULL,
  position = NULL,
  inherit.aes = FALSE,

  print = function(self) {
    if (!is.null(self$mapping)) {
      cat("mapping:", clist(self$mapping), "\n")
    }
    cat(snakeize(class(self$geom)[[1]]), ": ", clist(self$geom_params), "\n",
      sep = "")
    cat(snakeize(class(self$stat)[[1]]), ": ", clist(self$stat_params), "\n",
      sep = "")
    cat(snakeize(class(self$position)[[1]]), "\n")
  },

  compute_aesthetics = function(self, data, plot) {
    # For annotation geoms, it is useful to be able to ignore the default aes
    if (self$inherit.aes) {
      aesthetics <- defaults(self$mapping, plot$mapping)
    } else {
      aesthetics <- self$mapping
    }

    # Drop aesthetics that are set or calculated
    set <- names(aesthetics) %in% names(self$aes_params)
    calculated <- is_calculated_aes(aesthetics)
    aesthetics <- aesthetics[!set & !calculated]

    # Override grouping if set in layer
    if (!is.null(self$geom_params$group)) {
      aesthetics[["group"]] <- self$aes_params$group
    }

    # Old subsetting method
    if (!is.null(self$subset)) {
      include <- data.frame(plyr::eval.quoted(self$subset, data, plot$env))
      data <- data[rowSums(include, na.rm = TRUE) == ncol(include), ]
    }

    scales_add_defaults(plot$scales, data, aesthetics, plot$plot_env)

    # Evaluate and check aesthetics
    aesthetics <- compact(aesthetics)
    evaled <- lapply(aesthetics, eval, envir = data, enclos = plot$plot_env)

    n <- nrow(data)
    if (n == 0) {
      # No data, so look at longest evaluated aesthetic
      n <- max(vapply(evaled, length, integer(1)))
    }
    check_aesthetics(evaled, n)

    # Set special group and panel vars
    if (empty(data) && n > 0) {
      evaled$PANEL <- 1
    } else {
      evaled$PANEL <- data$PANEL
    }
    evaled <- data.frame(evaled, stringsAsFactors = FALSE)
    evaled <- add_group(evaled)
    evaled
  },

  compute_statistic = function(self, data, panel) {
    if (empty(data))
      return(data.frame())

    params <- self$stat$setup_params(data, self$stat_params)
    data <- self$stat$setup_data(data, params)
    self$stat$compute_layer(data, params, panel)
  },

  map_statistic = function(self, data, plot) {
    if (empty(data)) return(data.frame())

    # Assemble aesthetics from layer, plot and stat mappings
    aesthetics <- self$mapping
    if (self$inherit.aes) {
      aesthetics <- defaults(aesthetics, plot$mapping)
    }
    aesthetics <- defaults(aesthetics, self$stat$default_aes)
    aesthetics <- compact(aesthetics)

    new <- strip_dots(aesthetics[is_calculated_aes(aesthetics)])
    if (length(new) == 0) return(data)

    # Add map stat output to aesthetics
    stat_data <- plyr::quickdf(lapply(new, eval, data, baseenv()))
    names(stat_data) <- names(new)

    # Add any new scales, if needed
    scales_add_defaults(plot$scales, data, new, plot$plot_env)
    # Transform the values, if the scale say it's ok
    # (see stat_spoke for one exception)
    if (self$stat$retransform) {
      stat_data <- scales_transform_df(plot$scales, stat_data)
    }

    cunion(stat_data, data)
  },

  compute_geom_1 = function(self, data) {
    if (empty(data)) return(data.frame())
    data <- self$geom$setup_data(data, c(self$geom_params, self$aes_params))

    check_required_aesthetics(
      self$geom$required_aes,
      c(names(data), names(self$aes_params)),
      snake_class(self$geom)
    )

    data
  },

  compute_position = function(self, data, panel) {
    if (empty(data)) return(data.frame())

    params <- self$position$setup_params(data)
    data <- self$position$setup_data(data, params)

    self$position$compute_layer(data, params, panel)
  },

  compute_geom_2 = function(self, data) {
    # Combine aesthetics, defaults, & params
    self$geom$use_defaults(data, self$aes_params)
  },

  draw_geom = function(self, data, panel, coord) {
    if (empty(data)) return(list(zeroGrob()))

    self$geom$draw_layer(data, self$geom_params, panel, coord)
  }
)

is.layer <- function(x) inherits(x, "Layer")


find_subclass <- function(super, class) {
  name <- paste0(super, camelize(class, first = TRUE))
  if (!exists(name)) {
    stop("No ", tolower(super), " called ", name, ".", call. = FALSE)
  }

  obj <- get(name)
  if (!inherits(obj, super)) {
    stop("Found object is not a ", tolower(super), ".", call. = FALSE)
  }

  obj
}
