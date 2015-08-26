\name{simulate.ctmm}
\alias{simulate.ctmm}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
Simulate a continuous-time movement model
}
\description{
This function generates an \eqn{O(n)} hidden-Markov simulation of continuous-time movement models described in Fleming et al (2014) and Fleming et al (2015).
}
\usage{
\S3method{simulate}{ctmm}(object,nsim=1,seed=NULL,t=c(0),...)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{object}{ A \code{ctmm} movement-model in the same format as the output of \code{\link{ctmm.fit}} or \code{\link{variogram.fit}}.}
  \item{nsim}{Not supported.}
  \item{seed}{Optional random seed to fix.}
  \item{t}{Array of numeric time values over which the process will be simulated.}
  \item{...}{Unused options.}
}
\details{
Details of the movement model parameters can be found in \code{\link{ctmm.fit}}.
}

\value{ A simulated animal-tracking \code{telemetry} object with components \code{t}, \code{x}, and \code{y}. }

\references{
C. H. Fleming, J. M. Calabrese, T. Mueller, K.A. Olson, P. Leimgruber, and W. F. Fagan. (2014). From fine-scale foraging to home ranges: A semi-variance approach to identifying movement modes across spatiotemporal scales. \href{http://www.jstor.org/discover/10.1086/675504}{The American Naturalist, 183(5), E154-E167.}

C. H. Fleming and Y. Subasi and J. M. Calabrese. (2015). A maximum-entropy description of animal movement. \href{http://journals.aps.org/pre/abstract/10.1103/PhysRevE.91.032107}{Physical Review E, 91, 032107.}
}


\author{ Chris H. Fleming. }
% \note{ }

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{ \code{\link{ctmm.fit}} }

\examples{
#Load package and data
library(ctmm)

#prepare simulation parameters
t <- 1:1000
m1 <- ctmm(tau=c(100,10),sigma=10,mu=c(0,0))

#simulate data
s1 <- simulate(m1,t=t)

#plot data with Gaussian model
plot(s1,CTMM=m1)
}

% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
%\keyword{ ~kwd1 }
%\keyword{ ~kwd2 }% __ONLY ONE__ keyword per line