#' @inheritParams grid::curveGrob
#' @export
#' @rdname geom_segment
geom_curve <- function(mapping = NULL, data = NULL, stat = "identity",
  position = "identity", curvature = 0.5, angle = 90, ncp = 5, arrow = NULL,
  lineend = "butt", na.rm = FALSE, inherit.aes = TRUE, ...)
{
  layer(
    data = data,
    mapping = mapping,
    stat = stat,
    geom = GeomCurve,
    position = position,
    inherit.aes = inherit.aes,
    params = list(
      arrow = arrow,
      curvature = curvature,
      angle = angle,
      ncp = ncp,
      lineend = lineend,
      na.rm = na.rm,
      ...
    )
  )
}

#' @rdname ggplot2-ggproto
#' @format NULL
#' @usage NULL
#' @export
GeomCurve <- ggproto("GeomCurve", Geom,
  draw_panel = function(data, panel_scales, coord, curvature = 0.5, angle = 90,
                        ncp = 5, arrow = NULL, lineend = "butt", na.rm = FALSE) {

    data <- remove_missing(data, na.rm = na.rm,
                           c("x", "y", "xend", "yend", "linetype", "size", "shape"),
                           name = "geom_curve")

    if (empty(data)) return(zeroGrob())

    if (!coord$is_linear()) {
      warning("geom_curve is not implemented for non-linear coordinates",
        call. = FALSE)
    }
    trans <- coord$transform(data, panel_scales)
    curveGrob(
      trans$x, trans$y, trans$xend, trans$yend,
      default.units = "native",
      curvature = curvature, angle = angle, ncp = ncp,
      square = FALSE, squareShape = 1, inflect = FALSE, open = TRUE,
      gp = gpar(
        col = alpha(trans$colour, trans$alpha),
        lwd = trans$size * .pt,
        lty = trans$linetype,
        lineend = trans$lineend),
      arrow = arrow
    )
  },

  required_aes = c("x", "y", "xend", "yend"),

  default_aes = aes(colour = "black", size = 0.5, linetype = 1, alpha = NA),

  draw_key = draw_key_path
)
