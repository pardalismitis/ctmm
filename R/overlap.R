# overlap <- function(object,...) UseMethod("overlap") #S3 generic

# forwarding function for list of a particular datatype
overlap <- function(object,CTMM=NULL,level=0.95,...)
{
  CLASS <- class(object[[1]])
  
  if(CLASS=="ctmm")
  { OverlapFun <- overlap.ctmm }
  else if(CLASS=="telemetry")
  {
    # Generate aligned UDs
    object <- akde(object,CTMM=CTMM,...)
    OverlapFun <- overlap.UD
  }
  else if(CLASS=="UD")
  { OverlapFun <- overlap.UD }
  
  n <- length(object)
  OVER <- array(0,c(n,n,3))
  # tabulate overlaps
  for(i in 1:n)
  {
    for(j in (i+1):n)
    { if(j<=n) { OVER[i,j,] <- OverlapFun(object[c(i,j)],CTMM=CTMM[c(i,j)],level=level,...) } }
  }
  
  # symmetrize matrix
  OVER <- OVER + aperm(OVER,c(2,1,3))
  
  # fix diagonals
  diag(OVER[,,1]) <- diag(OVER[,,2]) <- diag(OVER[,,3]) <- 1
  
  dimnames(OVER) <- list(names(object),names(object),c("low","ML","high"))
  
  return(OVER)
  # utils::getS3method("overlap",CLASS)(object,...)
}


overlap.ctmm <- function(object,CTMM,level=0.95,...)
{
  CTMM1 <- object[[1]]
  CTMM2 <- object[[2]]
  
  # ML parameters
  par <- NULL
  
  par <- c(par,CTMM1$mu[1,])
  par <- c(par,CTMM1$sigma@par)

  par <- c(par,CTMM2$mu[1,])
  par <- c(par,CTMM2$sigma@par)
  
  D <- function(p)
  {
    CTMM1$mu[1,] <- p[1:2]
    CTMM1$sigma <- covm(p[3:5])
    
    CTMM2$mu[1,] <- p[6:7]
    CTMM2$sigma <- covm(p[8:10])
    
    return(BhattacharyyaD(CTMM1,CTMM2))
  }
  
  # propagate uncertainty
  grad <- numDeriv::grad(D,par)
  VAR <- 0
  
  VAR <- VAR + grad[1:2] %*% CTMM1$COV.mu %*% grad[1:2]
  if(CTMM1$isotropic)
  { VAR <- VAR + grad[3] * CTMM1$COV[1,1] * grad[3] }
  else
  { VAR <- VAR + grad[3:5] %*% CTMM1$COV[1:3,1:3] %*% grad[3:5] }
    
  VAR <- VAR + grad[6:7] %*% CTMM1$COV.mu %*% grad[6:7]
  if(CTMM1$isotropic)
  { VAR <- VAR + grad[8] * CTMM1$COV[1,1] * grad[8] }
  else
  { VAR <- VAR + grad[8:10] %*% CTMM1$COV[1:3,1:3] %*% grad[8:10] }
  
  VAR <- as.numeric(VAR)
  
  # this quantity is roughly chi-square
  MLE <- BhattacharyyaD(CTMM1,CTMM2)
  CI <- chisq.ci(MLE,COV=VAR,alpha=1-level)
  
  # transform from (square) distance to overlap measure
  CI <- exp(-rev(CI))
  names(CI) <- c("low","ML","high")
  
  if(level) { return(CI) }
  else { return(list(MLE=MLE,VAR=VAR)) }
}

# square distance between stationary Gaussian distributions
BhattacharyyaD <- function(CTMM1,CTMM2)
{
  sigma <- (CTMM1$sigma + CTMM2$sigma)/2
  mu <- CTMM1$mu[1,] - CTMM2$mu[1,]
  
  D <- as.numeric(mu %*% solve(sigma) %*% mu)/8 + log(det(sigma)/sqrt(det(CTMM1$sigma)*det(CTMM2$sigma)))/2

  return(D)
}

#overlap density function
overlap.UD <- function(object,CTMM,level=0.95,...)
{
  dr <- object[[1]]$dr
  dA <- prod(dr)
  
  OVER <- sqrt(object[[1]]$PDF * object[[2]]$PDF)

  # overlap point estimate
  OVER <- sum(OVER)*dA
  
  if(!is.null(CTMM))
  {
    # calculate Gaussian overlap distance^2 variance
    CI <- overlap.ctmm(CTMM,level=FALSE)

    # Bhattacharyya distances    
    D <- -log(OVER)
    COV.D <- CI$VAR
    
    # calculate new distance^2 with KDE point estimate
    CI <- chisq.ci(D,COV=COV.D,alpha=1-level)
    
    # transform from (square) distance to overlap measure
    OVER <- exp(-rev(CI))
    
  }
  else
  { OVER <- c(NA,OVER,NA) }
  
  names(OVER) <- c("low","ML","high")
  return(OVER)
}


# CALCULATE A BUNCH OF AKDE UDs ON THE SAME GRID
# (C) Kevin Winner & C.H. Fleming (2016)
akde.list <- function(data,CTMM,VMM=NULL,debias=TRUE,smooth=TRUE,error=0.001,res=10,grid=NULL,...)
{
  n.instances <- length(data)
  
  #initialize per-instance vars that need to be tracked
  HP.list   <- vector("list", n.instances)
  H.list    <- vector("list", n.instances)
  UD.list   <- vector("list", n.instances)
  n.samples.total <- 0
  
  #step 1: compute the optimal bandwidths for each instance
  # if (!silent)
  #  cat("Computing optimal bandwidths\n")
  for (i.instance in 1:n.instances)
  {
    #alias for readability
    instance <- data[[i.instance]]
    n.samples <- length(instance$x)
    n.samples.total <- n.samples.total + n.samples
    
    ## START BACK HERE ##
    
    #bandwidth calculations for this instance
    HP.list[[i.instance]] <- bandwidth(data = instance, CTMM = CTMM[[i.instance]], VMM=VMM[[i.instance]], verbose = TRUE,...)
    COL <- length(HP.list[[1]]$h)
    H.list[[i.instance]]  <- prepare.H(HP.list[[i.instance]]$H,length(instance$t))
    #reshape H
    H.list[[i.instance]]  <- array(H.list[[i.instance]], c(n.samples, COL * COL)) #TODO: magic numbers
  }
  
  #step 2: compute a grid for all UDs
  # if (!silent)
  #  cat("Computing the grid\n")
  H.all <- do.call("rbind", H.list)
  H.all <- array(H.all, c(n.samples.total, COL, COL))
  data.all <- do.call("rbind", data)
  dr <- vector("numeric", COL)
  dr[1] <- sqrt(min(sapply(HP.list, function(i) { i$H[1,1] })))
  dr[2] <- sqrt(min(sapply(HP.list, function(i) { i$H[2,2] })))
  if(COL==3) { dr[3] <- sqrt(min(sapply(HP.list, function(i) { i$H[3,3] }))) }
  dr    <- dr / res
  
  grid    <- kde.grid(data.all, H.all, alpha = error, dr = dr)
  dH.orig <- grid$dH
  
  #now align all UDs to the grid
  sample.position <- 1 #track position of next sample to read out
  for (i.instance in 1:n.instances)
  {
    # if (!silent)
    #  cat(sprintf("Aligning UD for instance %d/%d\n", i.instance, n.instances))
    
    #repeated work, but cheap and more readable than storing from step 1
    instance <- data[[i.instance]]
    n.samples <- length(instance$x)
    
    #remember when we reshaped H? yeah undo that
    H.list[[i.instance]] <- array(H.list[[i.instance]], c(n.samples, COL, COL))
    
    grid$dH <- dH.orig[sample.position:(sample.position + n.samples - 1),]
    
    UD.list[[i.instance]] <- akde(data[[i.instance]],CTMM=HP.list[[i.instance]],debias=debias,smooth=smooth,error=error,res=res,grid=grid,...)
    
    sample.position <- sample.position + n.samples
  }
  
  names(UD.list) <- names(data)
  return(UD.list)
}

###################
# average aligned UDs
mean.UD <- function(x,...)
{
  info <- mean.info(x)
  dV <- prod(x[[1]]$dr)
  n <- length(x)
  N <- sum(sapply(x,function(y){ y$DOF.area }))
  
  M <- lapply(x,function(ud){ ud$PDF })
  M <- Reduce('+',M)
  M <- M/n # now the average PDF
  
  x <- x[[1]]
  x$PDF <- M
  attr(x,"info") <- info
  x$DOF.area <- 0*x$DOF.area + N
  
  x$H <- NULL
  x$h <- NULL
  x$DOF.H <- NA
  x$bias <- NULL
  x$weights <- NULL
  x$MISE <- NULL
  
  M <- M*dV # now the average cell PMF
  x$CDF <- pmf2cdf(M)
  
  return(x)
}

##################
Tsquared <- function(CTMM1,CTMM2,spatial=TRUE)
{
  DOF <- 0
  chi.square <- 0
  CTMM <- list(CTMM1,CTMM2)
  rm(CTMM1,CTMM2)
  
  # BM/IOU versus IID is infinitely different
  TEST <- is.null(CTMM[[1]]$tau) && !is.null(CTMM[[2]]$tau[1]) && CTMM[[2]]$tau[1]==Inf
  TEST <- TEST || (is.null(CTMM[[2]]$tau) && !is.null(CTMM[[1]]$tau[1]) && CTMM[[1]]$tau[1]==Inf)
  if(TEST) { return(list(chi.square=Inf,DOF=0,p=0)) }
  
  # periodic mean parameters not yet supported because of COV.mu structure being weird !!!

  # switch from area to variance
  if(!spatial)
  {
    for(i in 1:2)
    {
      if(!CTMM[[i]]$isotropic)
      {
        CTMM[[i]]$COV <- area2var(CTMM[[i]])
        NAMES <- dimnames(CTMM[[i]]$COV)[[1]]
        NAMES[NAMES=="variance"] <- "area"
        dimnames(CTMM[[i]]$COV) <- list(NAMES,NAMES)
        
        CTMM[[i]]$sigma <- covm(mean(diag(CTMM[[i]]$sigma)),isotropic=TRUE)
        
        CTMM[[i]]$isotropic <- TRUE
      }
    }
  }
  
  # mean parameters
  if(spatial && CTMM[[1]]$range && CTMM[[2]]$range)
  {
    # pooled precision matrix
    precision <- PDsolve(CTMM[[1]]$COV.mu) + PDsolve(CTMM[[2]]$COV.mu)
    # differece in paramters
    theta.diff <- c(CTMM[[1]]$mu - CTMM[[2]]$mu)
    # chi-square for 2D mean
    chi.square <- chi.square + c(theta.diff %*% precision %*% theta.diff)
    DOF <- DOF + length(theta.diff)
  }
  
  ## autocorrelation parameters
  # null objects
  NAMES.1 <- dimnames(CTMM[[1]]$COV)[[1]]
  NAMES.2 <- dimnames(CTMM[[2]]$COV)[[1]]
  NAMES.L <- list(NAMES.1,NAMES.2)
  NAMES <- union( NAMES.1 , NAMES.2 )
  precision <- matrix(0,length(NAMES),length(NAMES))
  theta.diff <- rep(0,length(NAMES))
  
  # combined precision information
  names(theta.diff) <- NAMES
  dimnames(precision) <- list(NAMES,NAMES)
  
  # timescale correlation parameters
  SUB <- startsWith(NAMES,"tau ")
  if(any(SUB))
  {
    # consistent naming...
    for(i in 1:2) { if(!is.null(CTMM[[i]]$tau)) { names(CTMM[[i]]$tau) <- paste("tau",names(CTMM[[i]]$tau)) } }
    
    # maybe need to convert to comparable parameters
    if((CTMM[[1]]$range!=CTMM[[2]]$range) && ("tau position" %in% NAMES))
    {
      for(i in 1:2)
      {
        # convert tau to 1/tau
        CTMM[[i]]$tau[1] <- 1/CTMM[[i]]$tau[1]
        # update parameter-covariance matrix
        if("tau position" %in% NAMES.L[[i]])
        {
          CTMM[[i]]$COV["tau position",] <- -CTMM[[i]]$tau[1]^2 * CTMM[[i]]$COV["tau position",]
          CTMM[[i]]$COV[,"tau position"] <- -CTMM[[i]]$tau[1]^2 * CTMM[[i]]$COV[,"tau position"]
        }
        
        if(CTMM[[i]]$range)
        {
          # update parameter-covariance matrix
          J <- rbind( c(CTMM[[i]]$tau[1],CTMM[[i]]$sigma@par[1]) , c(0,1) )
          CTMM[[i]]$COV[c("area","tau position"),] <- J %*% CTMM[[i]]$COV[c("area","tau position"),]
          CTMM[[i]]$COV[,c("area","tau position")] <- CTMM[[i]]$COV[,c("area","tau position")] %*% t(J)
          
          # convert location-covariances to diffusion matrices
          CTMM[[i]]$sigma <- CTMM[[i]]$sigma * CTMM[[i]]$tau[1]
          CTMM[[i]]$sigma@par[1] <- CTMM[[i]]$sigma@par[1] * CTMM[[i]]$tau[1]
        }
      }
    }
    
    SIGN <- c(1,-1)
    for(i in 1:2)
    {
      if(!is.null(CTMM[[i]]$tau))
      {
        SUB <- names(CTMM[[i]]$tau) %in% NAMES
        SUB <- names(CTMM[[i]]$tau)[SUB]
        theta.diff[SUB] <- theta.diff[SUB] + SIGN[i]*CTMM[[i]]$tau[SUB]
      }
    }
    
  } # end taus
  
  # covariance parameters (this must come after potential diffusion transformation)
  if(CTMM[[1]]$isotropic && CTMM[[2]]$isotropic)
  { SUB <- "area" }
  else if(CTMM[[1]]$isotropic || CTMM[[2]]$isotropic)
  {
    # angle is not really relevant here, I don't think???, but eccentricity definitely is
    SUB <- which(NAMES=="angle")
    NAMES <- NAMES[-SUB]
    precision <- precision[-SUB,-SUB]
    theta.diff <- theta.diff[-SUB]
    SUB <- c("area","eccentricity")
    DOF <- DOF - 1
    # if eccentricity uncertainty is large, does this limit to the next case???
  }
  else
  { SUB <- c("area","eccentricity","angle") }
  # naive covariance differences
  theta.diff[SUB] <- CTMM[[1]]$sigma@par[SUB] - CTMM[[2]]$sigma@par[SUB]
  # clean up angle differences
  if("angle" %in% SUB)
  { 
    theta.diff["angle"] <- theta.diff["angle"] %% pi
    if(theta.diff["angle"]>pi/2) { theta.diff["angle"] <- pi - theta.diff["angle"] }
  }
  
  # combine precision matrices after transformation
  precision[NAMES.1,NAMES.1] <- PDsolve(CTMM[[1]]$COV[NAMES.1,NAMES.1])
  precision[NAMES.2,NAMES.2] <- precision[NAMES.2,NAMES.2] + PDsolve(CTMM[[2]]$COV[NAMES.2,NAMES.2])
  
  chi.square <- chi.square + c(theta.diff %*% precision %*% theta.diff)
  DOF <- DOF + length(theta.diff)
  
  # circulation needs to be flipped before I will include this. Too much trouble with period !!!
  
  # calculate p-value
  p <- 1 - stats::pchisq(chi.square,DOF)
  
  return(list(chi.square=chi.square,DOF=DOF,p=p))
}
