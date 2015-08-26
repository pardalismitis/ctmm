## ----  fig.show='hold'---------------------------------------------------
library(ctmm)
data(buffalo)
cilla <- buffalo[[1]]
plot(cilla)
title("1 Buffalo")
plot(buffalo,col=rainbow(length(buffalo),alpha=0.5))
title("5 Buffalo")

## ----  fig.show='hold'---------------------------------------------------
var <- variogram(cilla)
plot(var,fraction=0.005)
title("zoomed in")
plot(var,fraction=0.65,alpha=0.5)
title("zoomed out")

## ----  fig.show='hold'---------------------------------------------------
m0 <- ctmm(sigma=23*1000^2) # 23 km^2 in m^2
m1 <- ctmm(sigma=23*1000^2,tau=6*24*60^2) # and 6 days in seconds
plot(var,CTMM=m0,fraction=0.65,alpha=0.5,col.CTMM="red")
title("m0")
plot(var,CTMM=m1,fraction=0.65,alpha=0.5,col.CTMM="purple")
title("m1")

## ----  fig.show='hold'---------------------------------------------------
m2 <- ctmm(sigma=23*1000^2,tau=c(6*24*60^2,1*60^2)) # and 1 hour in seconds
plot(var,CTMM=m1,fraction=0.002,col.CTMM="purple")
title("m1")
plot(var,CTMM=m2,fraction=0.002,col.CTMM="blue")
title("m2")

## ----  fig.show='hold'---------------------------------------------------
plot(var,CTMM=m1,fraction=0.65,alpha=0.5,col.CTMM="purple")
title("m1")
plot(var,CTMM=m2,fraction=0.65,alpha=0.5,col.CTMM="blue")
title("m2")

## ----  fig.show='hold'---------------------------------------------------
# simulate fake buffalo with the same sampling schedule
willa <- simulate(m2,t=cilla$t)
plot(willa)
title("simulation")
# now calculate and plot its variogram
var2 <- variogram(willa)
plot(var2,CTMM=m2,fraction=0.65,alpha=c(0.5,0.05),col.CTMM="blue")
title("simulation")

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

## ----  fig.show='hold'---------------------------------------------------
M0 <- ctmm.fit(cilla,m0)
summary(M0)

## ----  fig.show='hold'---------------------------------------------------
M1 <- ctmm.fit(cilla,m1)
summary(M1)

## ----  fig.show='hold'---------------------------------------------------
M2 <- ctmm.fit(cilla,m2)
summary(M2)

## ----  fig.show='hold'---------------------------------------------------
TAB <- rbind( c(M0$AICc,M0$DOF.mu) , c(M1$AICc,M1$DOF.mu) , c(M2$AICc,M2$DOF.mu) )
colnames(TAB) <- c("AICc","DOF(mu)")
rownames(TAB) <- c("M0","M1","M2")
TAB

## ----  fig.show='hold'---------------------------------------------------
plot(var,CTMM=list(M0,M1,M2),col.CTMM=c("red","purple","blue"),fraction=0.65,alpha=0.5)
title("zoomed out")
plot(var,CTMM=list(M0,M1,M2),col.CTMM=c("red","purple","blue"),fraction=0.002,alpha=0.5)
title("zoomed in")
