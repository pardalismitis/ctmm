## ----  fig.show='hold'---------------------------------------------------
library(ctmm)
data("buffalo")
Cilla <- buffalo$Cilla
plot(Cilla)
title("1 Buffalo")
plot(buffalo,col=rainbow(length(buffalo)))
title("5 Buffalo")

## ----  fig.show='hold'---------------------------------------------------
SVF <- variogram(Cilla)
level <- c(0.5,0.95) # 50% and 95% CIs
xlim <- c(0,12 %#% "hour") # 0-12 hour window
plot(SVF,xlim=xlim,level=level)
title("zoomed in")
plot(SVF,fraction=0.65,level=level)
title("zoomed out")

## ----  fig.show='hold'---------------------------------------------------
m.iid <- ctmm(sigma=23 %#% "km^2")
m.ou <- ctmm(sigma=23 %#% "km^2",tau=6 %#% "day")
plot(SVF,CTMM=m.iid,fraction=0.65,level=level,col.CTMM="red")
title("Independent and identically distributed data")
plot(SVF,CTMM=m.ou,fraction=0.65,level=level,col.CTMM="purple")
title("Ornstein-Uhlenbeck movement")

## ----  fig.show='hold'---------------------------------------------------
m.ouf <- ctmm(sigma=23 %#% "km^2",tau=c(6 %#% "day",1 %#% "hour"))
plot(SVF,CTMM=m.ou,level=level,col.CTMM="purple",xlim=xlim)
title("Ornstein-Uhlenbeck movement")
plot(SVF,CTMM=m.ouf,level=level,col.CTMM="blue",xlim=xlim)
title("Ornstein-Uhlenbeck-F movement")

## ----  fig.show='hold'---------------------------------------------------
plot(SVF,CTMM=m.ou,fraction=0.65,level=level,col.CTMM="purple")
title("Ornstein-Uhlenbeck movement")
plot(SVF,CTMM=m.ouf,fraction=0.65,level=level,col.CTMM="blue")
title("Ornstein-Uhlenbeck-F movement")

## ----  fig.show='hold'---------------------------------------------------
# simulate fake buffalo with the same sampling schedule
willa <- simulate(m.ouf,t=Cilla$t)
plot(willa)
title("simulation")
# now calculate and plot its variogram
SVF2 <- variogram(willa)
plot(SVF2,CTMM=m.ouf,fraction=0.65,level=level,col.CTMM="blue")
title("simulation")

## ---- fig.show='hold'----------------------------------------------------
data("gazelle")
SVF3 <- variogram(gazelle[[18]])
plot(SVF3,fraction=0.85,level=level)
title("Default method")
# 1, 5, 25 hour sampling intervals
dt <- c(1,5,25) %#% "hour"
SVF3 <- variogram(gazelle[[18]],dt=dt)
plot(SVF3,fraction=0.85,level=level)
title("Multi method")

## ---- fig.show='hold'----------------------------------------------------
# buffalo 4 is bad
SVF4 <- lapply(buffalo[-4],variogram)
SVF4 <- mean(SVF4)
plot(SVF4,fraction=0.35,level=level)
title("Population variogram")

## ----  fig.show='hold', echo=FALSE---------------------------------------
# ARGOS type errors
curve(1+x,0,5,xlab="Short time lag",ylab="Semi-variance",ylim=c(0,6))
points(c(0,0),c(0,1))
title("ARGOS")
# detector array type errors (qualitatively only)
curve((1-exp(-2*x))/(1-exp(-2/4)),0,1/4,xlab="Short time lag",ylab="Semi-variance",ylim=c(0,6),xlim=c(0,5),add=FALSE)
curve(3/4+x,1/4,5,xlab="Short time lag",ylab="Semi-variance",ylim=c(0,6),add=TRUE,xlim=c(0,5))
points(1/4,1)
title("Detector Array")

## ------------------------------------------------------------------------
DATA <- as.telemetry(system.file("extdata","leroy.csv.gz",package="move"))
# default model guess
GUESS <- ctmm.guess(DATA,interactive=FALSE)
# first fit without telemetry error
FITS <- list()
FITS$NOERR <- ctmm.fit(DATA,GUESS)
# second fit based on first with telemetry error
GUESS <- FITS$NOERR
GUESS$error <- TRUE
FITS$ERROR <- ctmm.fit(DATA,GUESS)
# model improvement
summary(FITS)

## ----  fig.show='hold'---------------------------------------------------
M.IID <- ctmm.fit(Cilla,m.iid)
summary(M.IID)

## ----  fig.show='hold'---------------------------------------------------
M.OU <- ctmm.fit(Cilla,m.ou)
summary(M.OU)

## ----  fig.show='hold'---------------------------------------------------
M.OUF <- ctmm.fit(Cilla,m.ouf)
summary(M.OUF)

## ----  fig.show='hold'---------------------------------------------------
FITS <- list(IID=M.IID,OU=M.OU,OUF=M.OUF)
summary(FITS)

## ------------------------------------------------------------------------
FITZ <- ctmm.select(Cilla,m.ouf,verbose=TRUE,level=1)
summary(FITZ)

## ----  fig.show='hold'---------------------------------------------------
plot(SVF,CTMM=FITS,col.CTMM=c("red","purple","blue"),fraction=0.65,level=0.5)
title("zoomed out")
plot(SVF,CTMM=FITS,col.CTMM=c("red","purple","blue"),xlim=xlim,level=0.5)
title("zoomed in")

