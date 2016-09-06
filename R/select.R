###################################################
# Calculate good CIs for other functions
confint.ctmm <- function(model,alpha=0.05)
{
  tau <- model$tau
  tau <- tau[tau<Inf]
  K <- length(tau)
  
  COV <- model$COV
  
  par <- NULL
  NAME <- NULL
  
  # timescale uncertainty: can hit 0 and Inf
  if(K>0)
  {
    NAME <- paste("tau",names(tau))
    for(k in 1:K)
    { par <- rbind(par,ci.tau(tau[k],COV[NAME[k],NAME[k]],alpha=alpha)) }
  }
  
  # circulation period
  circle <- model$circle
  if(circle)
  {
    NAME <- c(NAME,"circle")
    par <- rbind(par,ci.tau(circle,COV["circle","circle"],alpha=alpha,min=-Inf))
  }  
  
  # standard area uncertainty: chi-square
  NAME <- c("area",NAME)
  GM.sigma <- model$sigma@par["area"]
  COV <- COV["area","area"] 
  par <- rbind(chisq.ci(GM.sigma,COV=COV,alpha=alpha),par)
  
  rownames(par) <- NAME
  
  return(par)
}

# timescale uncertainty: can hit 0 and Inf
ci.tau <- function(tau,COV,alpha=0.05,min=0,max=Inf)
{
  z <- stats::qnorm(1-alpha/2)
  
  # tau normal for lower CI
  CI <- tau + c(1,-1)*z*sqrt(COV)
  
  # lower CI of f==1/tau normal for upper CI of tau
  CI <- c(CI, (1/tau + c(1,-1)*z*sqrt(COV/tau^4))^-1)
  
  # take most conservative estimates
  CI <- range(CI)
  
  # enforce boundary constraints
  CI <- c(max(CI[1],min),min(CI[2],max))
  
  CI <- c(CI[1],tau,CI[2])
  return(CI)
}

###
summary.ctmm <- function(object,level=0.95,level.UD=0.95,...)
{
  CLASS <- class(object)
  if(CLASS=="ctmm")
  { return(summary.ctmm.single(object,level=level,level.UD=level.UD)) }
  else if(CLASS=="list")
  { return(summary.ctmm.list(object,level=level,level.UD=level.UD)) }
}

######################################################
# Summarize results
summary.ctmm.single <- function(object, level=0.95, level.UD=0.95, ...)
{
  if(is.na(level.UD)) { level.UD <- 1-exp(-1) } # normal mean area
  
  alpha <- 1-level
  alpha.UD <- 1-level.UD
  
  drift <- get(object$mean)
  
  CPF <- object$CPF
  circle <- object$circle
  tau <- object$tau
  if(length(tau)>0 && tau[1]==Inf) { range <- FALSE } else { range <- TRUE }
  tau <- tau[tau<Inf]
  K <- length(tau)
  
  AM.sigma <- mean(diag(object$sigma))
  GM.sigma <- object$sigma@par["area"]
  ecc <- object$sigma@par["eccentricity"]
  
  COV <- object$COV
  P <- nrow(COV)
  
  # where to store unit information
  name <- character(K+1)
  scale <- numeric(K+1)
  
  par <- confint.ctmm(object,alpha=alpha)
  
  # standard area to home-range area
  par[1,] <- -2*log(alpha.UD)*pi*par[1,]
  
  # pretty area units
  unit.list <- unit(par[1,2],"area")
  name[1] <- unit.list$name
  scale[1] <- unit.list$scale
  
  # pretty time units
  P <- nrow(par)
  if(P>1)
  {
    for(i in 2:P)
    {
      unit.list <- unit(par[i,2],"time")
      name[i] <- unit.list$name
      scale[i] <- unit.list$scale
    }
  }
  
  # can we estimate speed?
  if(continuity(object)>1)
  {
    COV <- area2var(object)
    
    # RMS velocity
    if(CPF)
    {
      Omega2 <- sum(c(2*pi,1)^2/tau^2)
      grad <- -2*c(2*pi,1)^2/tau^3
    }
    else
    {
      Omega2 <- 1/prod(tau)
      grad <- -Omega2/tau
    }
    
    # contribution from circulation
    omega2 <- 0
    if(circle)
    {
      omega2 <- (2*pi/circle)^2
      grad <- c(grad,-2*omega2/circle)
    }
    
    # contribution from sigma
    # GM.sigma <- cosh(ecc)*AM.sigma
    ms <- AM.sigma*(Omega2+omega2)
    grad <- c(Omega2+omega2, AM.sigma*grad)
    var.ms <- (grad) %*% COV %*% (grad)
    
    # include mean
    MSPEED <- drift@speed(object)
    ms <- ms + MSPEED$EST
    var.ms <- var.ms + MSPEED$VAR
    
    # root mean square velocity
    # pretty units
    rms <- sqrt(ms)
    unit.list <- unit(rms,"speed")
    name <- c(name,unit.list$name)
    scale <- c(scale,unit.list$scale)
    
    rms <- sqrt(norm.ci(ms,var.ms,alpha=alpha))
    
    par <- rbind(par,rms)
    rownames(par)[P+1] <- "speed"
  }
  
  # Fix unit choice
  par <- par/scale
  
  # affix units
  rownames(par) <- paste(rownames(par)," (",name,")",sep="")
  
  if(!range) { par <- par[-1,] } # delete off "area" (really diffusion)
  
  # anything else interesting from the mean function
  par <- rbind(drift@summary(object,level,level.UD),par)

  colnames(par) <- c("low","ML","high")

  SUM <- list()
  
  # affix DOF info
  # only valid for processes with a stationary mean
  if(object$range)
  {
    SUM$DOF <- c( DOF.mean(object) , DOF.area(object) )
    names(SUM$DOF) <- c( "mean","area")
  }
   
  SUM$CI <- par  
  
  return(SUM)
}
#methods::setMethod("summary",signature(object="ctmm"), function(object,...) summary.ctmm(object,...))

#DOF of area
DOF.area <- function(CTMM) { CTMM$sigma@par["area"]^2/CTMM$COV["area","area"] }

########
sort.ctmm <- function(x, decreasing=FALSE, IC="AICc", ...)
{
  ICS <- sapply(x,function(m){m[[IC]]})
  IND <- sort(ICS,method="quick",index.return=TRUE,decreasing=decreasing)$ix
  x <- x[IND]
}

#########
DOF.mean <- function(CTMM)
{
  DOF <- CTMM$DOF.mu
  DIM <- dim(DOF)
  
  if(!is.null(DIM))
  {
    # stationary contribution
    if(length(DIM)==4) { DOF <- DOF[,1,1,] }
    # average of x-y DOFs
    DOF <- mean(diag(DOF))
  }
  
  return(DOF)
}

########
summary.ctmm.list <- function(object, IC="AICc", ...)
{
  object <- sort.ctmm(object,IC=IC)
  DOF <- sapply(object,DOF.mean)
  ICS <- sapply(object,function(m){m[[IC]]})
  ICS <- ICS - ICS[[1]]
  ICS <- cbind(ICS,DOF)
  rownames(ICS) <- names(object)
  colnames(ICS) <- c(paste("d",IC,sep=""),"DOF[mean]")
  return(ICS)
}


###############
# keep removing uncertain parameters until AIC stops improving
ctmm.select <- function(data,CTMM,verbose=FALSE,level=0.99,IC="AICc",...)
{
  alpha <- 1-level
  drift <- get(CTMM$mean)
  
    # fit the intital guess
  CTMM <- ctmm.fit(data,CTMM,...)
  OLD <- ctmm()
  MODELS <- list(CTMM)
  # while progress is being made, keep going, keep going, ...
  while(!identical(CTMM,OLD))
  {
    GUESS <- list()
    
    # consider if some timescales are actually zero
    CI <- confint.ctmm(CTMM,alpha=alpha)
    if(length(CTMM$tau)==2)
    {
      Q <- CI["tau velocity",1]
      if(is.nan(Q) || (Q<=0))
      {
         GUESS[[length(GUESS)+1]] <- CTMM
         GUESS[[length(GUESS)]]$tau <- CTMM$tau[-length(CTMM$tau)]
      }
    }
    else if(length(CTMM$tau)==1)
    {
      Q <- CI["tau position",1]
      if(is.nan(Q) || (Q<=0))
      {
        GUESS[[length(GUESS)+1]] <- CTMM
        GUESS[[length(GUESS)]]$tau <- NULL
      }
    }
    
    # consider if there is no circulation
    if(CTMM$circle)
    {
      Q <- prod(CI["circle",c(1,3)])
      if(is.nan(Q) || (Q<=0))
      {
        GUESS[[length(GUESS)+1]] <- CTMM
        GUESS[[length(GUESS)]]$circle <- FALSE
      }
    }
    
    # consider if eccentricity is zero
    if(!CTMM$isotropic)
    {
      Q <- "eccentricity"
      Q <- stats::qnorm(alpha/2,mean=CTMM$sigma@par[Q],sd=sqrt(CTMM$COV[Q,Q]))
      if(Q <= 0)
      {
        GUESS[[length(GUESS)+1]] <- CTMM
        GUESS[[length(GUESS)]]$isotropic <- TRUE
        GUESS[[length(GUESS)]]$sigma <- covm(CTMM$sigma,isotropic=T)
      }
    }
    
    # consider if the mean could be more detailed
    GUESS <- c(GUESS,drift@refine(CTMM))
    
    # fit every model
    GUESS <- lapply(GUESS,function(g){ctmm.fit(data,g,...)})
    MODELS <- c(MODELS,GUESS)
    
    # what is the new best model?
    OLD <- CTMM
    MODELS <- sort.ctmm(MODELS)
    CTMM <- MODELS[[1]]
  }
  
  # name all of the models
  names(MODELS) <- sapply(MODELS,name.ctmm)
  
  # return the best or return the full list of models
  if(verbose) { return(MODELS) }
  else { return(MODELS[[1]]) }
}
  
  
name.ctmm <- function(CTMM)
{
  # base model
  if(length(CTMM$tau)==2)
  { NAME <- "OUF" }
  else if(length(CTMM$tau)==1)
  { NAME <- "OU" }
  else if(length(CTMM$tau)==0)
  { NAME <- "IID" }
  
  # isotropy
  if(CTMM$isotropic)
  { NAME <- c(NAME,"isotropic") }
  else
  { NAME <- c(NAME,"anisotropic") }
  
  # circulation
  if(CTMM$circle)
  { NAME <- c(NAME,"circle") }
  
  # mean
  drift <- get(CTMM$mean)
  NAME <- c(NAME,drift@name(CTMM))
  
  NAME <- paste(NAME,sep="",collapse=" ")
  return(NAME)
}
