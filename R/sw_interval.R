#' sw_interval: computes the limits of the felling date range
#'
#' @description This function computes the probability density function (PDF)
#'   and highest probability density interval (hdi) of the felling date range
#'   based on the observed number of sapwood rings, their chronological dating
#'   and the selected sapwood data and model.
#'
#' @param n_sapwood A `numeric`. The number of sapwood rings observed/measured.
#' @param last A `numeric`. The calendar year assigned to the outermost
#'   sapwood ring (optional, default = 0).
#' @param hdi A `logical.` If `TRUE`: the lower and upper limit of the
#' highest density interval (credible interval) is given. When `FALSE`: a matrix
#' is returned with scaled p values for each number of observed sapwood rings.
#' @param credMass  A `scalar` `[0, 1]` specifying the mass within the credible
#' interval (default = .954).
#' @param sw_data The name of the sapwood data set to use for modelling.
#' Should be one of [sw_data_overview()], or the path to a .csv file with
#' columns ´n_sapwood´ and ´count´.
#' @param densfun Name of the density function fitted to the sapwood data set.
#'   Should be one of:
#'   * _lognormal_ (the default value),
#'   * _normal_,
#'   * _weibull_,
#'   * _gammma_.
#' @param sep Should be "," (comma)  or ";" (semi-colon) and is used when a
#'   sapwood data set is provided from user-defined .csv-file.
#' @param plot A `logical`. If `TRUE` a plot is returned of the individual
#'   sapwood model and estimate of the felling date range.
#'   If `FALSE` a list with numeric output of the modelling process is returned.
#'
#' @export
#'
#' @return Depends on the value of `hdi`.
#'
#'  * `hdi = TRUE`: a `numeric vector` reporting the upper and lower limit
#'  of the hdi (attributes provide more detail on `credMass` and the applied
#'  sapwood model (`sw_data`)).
#'  * `hdi = FALSE`: a `matrix` with scaled p values for each number of
#'  observed sapwood rings.

sw_interval <- function(n_sapwood = NA,
                        last = 0,
                        hdi = FALSE,
                        credMass = 0.954,
                        sw_data = "Hollstein_1980",
                        densfun = "lognormal",
                        sep = ";",
                        plot = FALSE) {
     # check input
     if (is.na(n_sapwood)) {
          message(" --> no pdf/hdi can be returend when n_sapwood = NA")
          return(NA_integer_)
     }

     if (!is.numeric(n_sapwood)) {
          stop("\n --> n_sapwood must be a numeric value")
     }

     if (n_sapwood < 0) {
          stop("\n --> n_sapwood must be a positive number")
     }

     if (isTRUE(n_sapwood%%1 != 0)) {
          stop("\n --> n_sapwood must be an integer (no decimals allowed!)")
     }

     if (!sw_data %in% sw_data_overview()){
          sw_data <- "Hollstein_1980"
          message(" --> No sapwood data set specified,
                  defaults to 'Hollstein_1980'.")
     }

     if (is.na(credMass) || credMass <= 0 || credMass >= 1)
          stop(" --> credMass must be between 0 and 1")

     sw_model_params <- sw_model(sw_data, densfun = densfun, plot = FALSE)
     a <- sw_model_params$fit_parameters$estimate[1]
     sigma <- sw_model_params$fit_parameters$estimate[2]
     if (n_sapwood > sw_model_params$range[3]) {
          warning(paste0("--> ", n_sapwood,
                         " is a very high no. of sapwood rings.
                         Is this correct?"))
     }

     swr_n <- seq(n_sapwood, n_sapwood + 100, by = 1)
     year <- seq(last, last + 100, by = 1)
     p <- d.dens(
          densfun = densfun,
          x = swr_n,
          param1 = a,
          param2 = sigma,
          n = length(swr_n))
     pdf <- data.frame(year, swr_n, p)
     colnames(pdf) <- c("year", "n_sapwood", "p")

     # filter extreme low p values (e.g. when a very high no. of swr is observed)
     pdf <- subset(pdf, p > 0.0000001)

     # pdf$p[pdf$p < 0.000001] <- 0

     # scale density function to 1
     pdf$p <- pdf$p/sum(pdf$p)

     #compute limits of hdi-interval
     hdi_int <- hdi(x = pdf[, -1],a = "n_sapwood", b = "p",
                credMass = credMass)

     # Add calendar years to output when y is provided
     if (last == 0) {
             attr(hdi_int, "credMass") <- credMass
             attr(hdi_int, "sapwood_data") <- sw_data
             attr(hdi_int, "model") <- densfun
        }
     if (last != 0) {

             hdi_int[1] <- hdi_int[[1]] - n_sapwood + last
             hdi_int[2] <- hdi_int[[2]] - n_sapwood + last
        }

     attr(pdf, "sapwood_data") <- sw_data
     attr(pdf, "model") <- densfun
     attr(pdf, "credMass") <- credMass
     attr(pdf, "hdi") <- hdi_int

     if (hdi == FALSE & plot == FALSE){

          if (nrow(pdf) <= 1) {
               pdf[1,] <- c(last, n_sapwood, NA)
               warning("\n --> No upper limit for the hdi could be computed.")
          }

        return(pdf)

     } else if (hdi == TRUE & nrow(pdf) <= 1) {
          # when a very high number of swr is given, the pdf_matrix is empty
          # --> create hdi manually
          hdi_int <- c(last, NA_integer_, NA_integer_)
          names(hdi_int) <- c("lower", "upper", "p")
          attr(hdi_int, "credMass") <- credMass
          attr(hdi_int, "sapwood_data") <- sw_data
          attr(hdi_int, "model") <- densfun

          warning("\n --> No upper limit for the hdi could be computed.")

          return(hdi_int)

     } else if (plot == TRUE) {

        int_plot <- sw_interval_plot(x = pdf, credMass = credMass)
        suppressWarnings(print(int_plot))


     } else {
             attr(hdi_int, "credMass") <- credMass
             attr(hdi_int, "sapwood_data") <- sw_data
             attr(hdi_int, "model") <- densfun

             return(hdi_int)

          }
}


###############################################################################
# helper function to pick the appropriate Prob. Density Function (PDF).

d.dens <- function(densfun = densfun,
                   x = x,
                   param1 = 0,
                   param2 = 1,
                   log = FALSE,
                   n = 1) {
     if (densfun == "lognormal") {
          stats::dlnorm(
               x = x,
               meanlog = param1,
               sdlog = param2,
               log = log
          )
     } else if (densfun == "normal") {
          stats::dnorm(
               x = x,
               mean = param1,
               sd = param2,
               log = log
          )
     } else if (densfun == "weibull") {
          stats::dweibull(
               x = x,
               shape = param1,
               scale = param2,
               log = log
          )
     } else if (densfun == "gamma") {
          stats::dgamma(
               x = x,
               shape = param1,
               rate = param2,
               log = log
          )
     } else {
          stop(paste0("!!! '", densfun,
                      "' is not a supported distribution !!!"))
     }
}

###############################################################################
