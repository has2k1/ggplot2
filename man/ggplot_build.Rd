% Generated by roxygen2 (4.1.1): do not edit by hand
% Please edit documentation in R/plot-build.r
\name{ggplot_build}
\alias{ggplot_build}
\alias{layer_data}
\title{Build ggplot for rendering.}
\usage{
ggplot_build(plot)

layer_data(plot, i = 1L)
}
\arguments{
\item{plot}{ggplot object}
}
\description{
\code{ggplot_build} takes the plot object, and performs all steps necessary
to produce an object that can be rendered.  This function outputs two pieces:
a list of data frames (one for each layer), and a panel object, which
contain all information about axis limits, breaks etc. \code{layer_data}
is a helper function which returns the data for a given layer.
}
\seealso{
\code{\link{print.ggplot}} and \code{\link{benchplot}} for
 for functions that contain the complete set of steps for generating
 a ggplot2 plot.
}
\keyword{internal}

