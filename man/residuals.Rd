\name{residuals.ctmm}
\alias{residuals.ctmm}
\alias{residuals.telemetry}
\alias{correlogram}
\encoding{UTF-8}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{Calculate model fit residuals and assess their autocorrelation}
\description{
These functions calculate the residuals of a CTMM model, which should be standardized and IID if the model correctly specified.
A correlogram method is also provided to assess remaining autocorrelation.
This function is analogous to \code{acf}, but can handle missing data and multiple dimensions.
}
\usage{
\S3method{residuals}{ctmm}(object,data,...)

\S3method{residuals}{telemetry}(object,CTMM,...)

correlogram(data,dt=NULL,fast=TRUE,res=1,axes=c("x","y"))

}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{object}{\code{ctmm} model object or \code{telemetry} data object for calculating residuals.}
  \item{data}{\code{telemetry} data object or \code{data.frame} with time column \code{t} and data columns \code{axes}.}
  \item{CTMM}{\code{ctmm} model object.}
  \item{...}{Unused arguments.}
  \item{dt}{ Lag bin width. An ordered array will yield a progressive coarsening of the lags. Defaults to the median sampling interval.}
  \item{fast}{ Use the lag-weighted algorithm if \code{FALSE} or the FFT algorithm if \code{TRUE}. The slow algorithm outputs a progress bar.}
  \item{res}{Increase the discretization resolution for irregularly sampled data with \code{res>1}. Decreases bias at the cost of smoothness.}
  \item{axes}{Array of axes to calculate an average (isotropic) correlogram for.}
}
\details{
Given a \code{telemetry} dataset and \code{ctmm} model, \code{residuals} calculates the standardized residuals of the Kalman filter, which can be tested for independence. The residuals object can then be plotted with \code{plot} or fed into the \code{correlogram} method to test independence. Output of the correlogram can then be plotted as well, though \code{zoom} is much more useful.

When calculating correlograms, minimizing bias is more important than producing a overall smooth estimate. If \code{fast=TRUE}, then \code{res} needs to be large enough to resolve variability in the sampling interval (missing data is permitted). E.g., if the sampling interval is set to 15 minutes, but can be off by a minute or two, then \code{res=15} is a good choice.
}

\value{
\code{residuals} return a residual object (class \code{telemetry}, but flagged as residual) and \code{correlogram} returns a correlogram object (class \code{variogram}, but flagged as an ACF).
}
\references{
C. H. Fleming, D. Sheldon, E. Gurarie, W. F. Fagan, S. LaPoint, J. M. Calabrese.
Kálmán filters for continuous-time movement models.
\href{http://www.sciencedirect.com/science/article/pii/S1574954117301115}{Ecological Informatics, 40, 8-21 (2017)}.
}

\author{ C. H. Fleming}

\note{If the sampling schedule is irregular, permitting gaps, then the correlogram may not look good even if the model is correctly specified. In this case the correlogram of the residuals should be compared to the correlogram of simulated residuals, using "data" simulated from the fit model and with the same sampling schedule.}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{ \code{\link{plot.variogram}}, \code{\link{variogram}}. }

\examples{\donttest{
#Load package and data
library(ctmm)
data(buffalo)
Cilla <- buffalo$Cilla

#fit a model
GUESS <- ctmm.guess(Cilla,interactive=FALSE)
FIT <- ctmm.fit(Cilla,GUESS)

#calculate residuals
RES <- residuals(Cilla,FIT)

#scatter plot of residuals
plot(RES)

#calculate correlogram of residuals
# increase the res argument to account for sampling variability
ACF <- correlogram(RES,res=10)

#plot a day's worth of lags
plot(ACF[ACF$lag<=24*60^2,],fraction=1)
}}

% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
%\keyword{ ~kwd1 }
%\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line
