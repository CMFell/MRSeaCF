#' Assessing the influece of each correlated block on both the precision of the parameter estimates (COVRATIO statistics) and the sensitivity of model predictions (PRESS statistics).
#' 
#' @param model Fitted model object (glm, gamMRSea or gam)
#' @param id blocking structure
#' @param d2k (\code{default=NULL}). (n x k) Matrix of distances between all data points in \code{model} and all valid knot locations.
#' @param splineParams (\code{default=NULL}). List object containng output from runSALSA (e.g. knot locations for continuous covariates). See \code{\link{makesplineParams}} for more details of this object. 
#' @param save (\code{default=FALSE}). Logical stating whether plot should be saved into working directory.
#' 
#' @details
#' Always run \code{\link{timeInfluenceCheck}} first to see how long it will take to produce the plots.
#' 
#' @return
#' Two plots one each for COVRATIO and PRESS statistics, giving the influence of each block on precision of the parameter estimates and the sensitivity of model predictions.
#' List object:
#' \item{influenceData}{List of \code{blocks}, COVRATIO statistics and PRESS statistics used for making the plot of PRESS and COVRATIO statistics.}
#' \item{influencePoints}{Row id of blocks in \code{influenceData} that lie outside the 95\% quantile of COVRATIO statistics and above the 95\% quantile of PRESS statistics.}
#' 
#' @examples 
#' # load data
#' data(ns.data.re)
#' 
#' ns.data.re$blockid<-paste(ns.data.re$GridCode, ns.data.re$Year, ns.data.re$MonthOfYear, 
#'                     ns.data.re$DayOfMonth, sep='')
#' ns.data.re$blockid<-as.factor(ns.data.re$blockid)
#' 
#' model<-gamMRSea(birds ~ observationhour + as.factor(floodebb) + as.factor(impact),  
#'               family='poisson', data=ns.data.re)
#' 
#' timeInfluenceCheck(model, ns.data.re$blockid)
#' 
#' \dontrun{
#' # **WARNING** this example takes a long time
#' influences<-runInfluence(model, ns.data.re$blockid)
#' }
#' @export
#' 
runInfluence<-function(model, id, d2k=NULL, splineParams=NULL, save=FALSE, dots=FALSE){
  
  attributes(model$formula)$.Environment<-environment()
  response<-model$y
  
  if(class(model)[1]=='geeglm'){
    dat<- model$data
  }
  
  if(class(model)[1]=='gam'){
    dat<-model$model 
  }
  
  if(class(model)[1]=='gamMRSea' | class(model)[1]=='glm'){
    dat<-model$data 
  }
  
  
  print("Calculating COVRATIO and PRESS Statistics")
  
  # detach("package:mgcv")
  # require(mgcv)
  # 
  inflStore<- matrix(0,nrow=length(unique(id)), ncol=(length(coef(model))+2))
  counter<-1
  for(i in unique(id)){
    if(dots==TRUE){if((counter/100)%%1 == 0){cat(counter, '\n')}else{cat('.')}}
    rowsToDel<- which(id==i)
    pos<- which(i==unique(id))
    newData<- dat[-rowsToDel,]
    if(is.null(d2k)==F){
      dists<- d2k[-rowsToDel,]
    }
    if(class(model)[1]=='gamMRSea'){
      panels<-model$panels
      if(is.null(panels)) panels<-1:nrow(dat)
      newMod<-update(model, .~. ,data=newData, panels=panels[-rowsToDel])
    }else{
      newMod<-update(model, .~. ,data=newData)
    }
    inflStore[pos,(1:length(coef(model)))]<-newMod$coefficients
    nb<- as.matrix(model.matrix(model)[c(1),])
    nc<- as.matrix(inflStore[pos,1:length(coef(model))])
    if(length(pos==1)){
      presPred <- t(nb)%*%nc
    }else{
      presPred <- nb%*%nc  
    }
    inflStore[pos,ncol(inflStore)]<-sum((response[rowsToDel]-family(model)$linkinv(presPred))**2)
    if(class(model)[1]=='gamMRSea'){
      inflStore[pos,(ncol(inflStore)-1)]<-det(summary(newMod)$cov.robust)/det(summary(model)$cov.robust)
    }else{
      inflStore[pos,(ncol(inflStore)-1)]<-det(summary(newMod)$cov.scaled)/det(summary(model)$cov.scaled)
    }
    
    counter<-counter+1
  }
  
  numericblock<-as.numeric(unique(id))
  
  if(save==T){png("InfluenceMeasures_covratio.png", height=600, width=600)}else{devAskNewPage(ask=TRUE)}
  a<-inflStore[,(ncol(inflStore)-1)]
  quant<-quantile(a, probs=c(0.025, 0.975))
  outblocka<-which(a<quant[1] | a>quant[2])
  
  plot(numericblock, inflStore[,(ncol(inflStore)-1)], pch=20 , xlab="Omitted Block", ylab="COVRATIO Statistic", cex.lab=1.3, cex.axis=1.3, xaxt='n')
  axis(1, at=numericblock, labels=unique(id), las=0)
  abline(h=1)
  abline(h=quant[1], col='grey', lty=2)
  abline(h=quant[2], col='grey', lty=2)
  textxy(X=numericblock[outblocka], Y=a[outblocka],labs=unique(id)[outblocka], cex=0.8)
  if(save==T){dev.off()}
  
  
  # plot for press statistic
  b<-inflStore[,(ncol(inflStore))]
  quant<-quantile(b, probs=c(0.95))
  outblockb<-which(b>quant)
  
  if(save==T){png("InfluenceMeasures_press.png", height=600, width=600)}
  plot(numericblock, inflStore[,ncol(inflStore)], pch=20 , xlab="Omitted Block", ylab="PRESS Statistic", cex.lab=1.3, cex.axis=1.3, xaxt='n')
  axis(1, at=numericblock, labels=unique(id), las=0)
  abline(h=quant, col='grey', lty=2)
  textxy(X=numericblock[outblockb], Y=b[outblockb],unique(id)[outblockb], cex=0.8)
  if(save==T){dev.off()}else{devAskNewPage(ask=FALSE)}
  
  if(length(which(b=='Inf'))>0){
    cat(paste('Warning: no block labels for PRESS plot as', length(which(b=='Inf')), ' blocks have PRESS=Inf:\n\n ', list(which(b=='Inf'))))
    outblockb<-which(b=='Inf')
  }
  
  influenceData <- data.frame(blocks=numericblock, covratio=inflStore[,(ncol(inflStore)-1)], press=inflStore[,ncol(inflStore)])
  influencePoints <- list(covratio = outblocka, press=outblockb)
  
  
  return(list(influenceData=influenceData, influencePoints=influencePoints))
  
}


textxy<-function (X, Y, labs, m = c(0, 0), cex = 0.5, offset = 0.8, ...) 
{
  posXposY <- ((X >= m[1]) & ((Y >= m[2])))
  posXnegY <- ((X >= m[1]) & ((Y < m[2])))
  negXposY <- ((X < m[1]) & ((Y >= m[2])))
  negXnegY <- ((X < m[1]) & ((Y < m[2])))
  if (sum(posXposY) > 0) 
    text(X[posXposY], Y[posXposY], labs[posXposY], adj = c(0.5 - 
                                                             offset, 0.5 - offset), cex = cex, ...)
  if (sum(posXnegY) > 0) 
    text(X[posXnegY], Y[posXnegY], labs[posXnegY], adj = c(0.5 - 
                                                             offset, 0.5 + offset), cex = cex, ...)
  if (sum(negXposY) > 0) 
    text(X[negXposY], Y[negXposY], labs[negXposY], adj = c(0.5 + 
                                                             offset, 0.5 - offset), cex = cex, ...)
  if (sum(negXnegY) > 0) 
    text(X[negXnegY], Y[negXnegY], labs[negXnegY], adj = c(0.5 + 
                                                             offset, 0.5 + offset), cex = cex, ...)
}