#' Running SALSA for a spatial smooth with a CReSS basis
#'
#' This function fits a spatially adaptive two dimensional smooth of spatial coordinates with knot number and location selected by SALSA.
#'
#' @param model A model with no spatial smooth
#' @param salsa2dlist Vector of objects required for \code{runSALSA2D}: \code{fitnessMeasure}, \code{knotgrid}, \code{startKnots}, \code{minKnots}, code{maxKnots}, \code{r_seq}, \code{gap}, \code{interactionTerm}.
#' @param d2k (n x k) Matrix of distances between all data points in \code{model} and all valid knot locations specified in \code{knotgrid}
#' @param k2k (k x k) Matrix of distances between all valid knot locations specified in \code{knotgrid}
#' @param splineParams (default \code{=NULL}) List object containng output from runSALSA (e.g. knot locations for continuous covariates)
#' @param chooserad logical flag.  If FALSE (default) then the range parameter of the basis is chosen after the knot location and number. If TRUE, the range is assessed at every iteration of a knot move/add/drop.
#' @param panels Vector denoting the panel identifier for each data point (if robust standard errors are to be calculated). Defaults to data order index if not given.
#' @param suppress.printout (Default: \code{FALSE}. Logical stating whether to show the analysis printout.
#' @param tol Numeric stating the tolerance for the fitness Measure. e.g. tol=2 with AIC would only allow changes to be made if the AIC score improves by 2 units.
#' @param plot logical stating whether to print out the chosen knot locations at each iteration. \code{default = FALSE}.
#' @param basis One of 'gaussian' (default) or 'exponential'. Specifys what kind of local radial function to use (\code{\link{LRF.g}} or \code{\link{LRF.e}})
#' 
#' @references Scott-Hayward, L.; M. Mackenzie, C.Donovan, C.Walker and E.Ashe.  Complex Region Spatial Smoother (CReSS). Journal of computational and Graphical Statistics. 2013. doi: 10.1080/10618600.2012.762920
#'
#' @references Scott-Hayward, L.. Novel Methods for species distribution mapping including spatial models in complex regions: Chapter 5 for SALSA2D methods. PhD Thesis, University of St Andrews. 2013
#'
#' @details
#'
#'The object \code{salsa2dlist} contains parameters for the \code{runSALSA2D} function.
#'
#'    \code{fitnessMeasure}. The criterion for selecting the `best' model.  Available options: AIC, AIC_c, BIC, QIC_b, cv.gamMRSea (use cv.opts in salsa2dlist to specify seed, folds, cost function (Defaults: \code{cv.opts=list(cv.gamMRSea.seed=357, K=10, cost=function(y, yhat) mean((y - yhat)^2))})
#'
#'    \code{knotgrid}. A set of 'k' knot locations (k x 2 matrix or dataframe of coordinates).  May be made using \code{\link{getKnotgrid}}.
#'
#'    \code{startknots}. Starting number of knots (initialised as spaced filled locations).
#'
#'    \code{minKnots}. Minimum number of knots to be tried.
#'
#'    \code{maxKnots}. Maximum number of knots to be tried.
#'
#'    \code{gap}. The minimum gap between knots (in unit of measurement of coordinates).
#'    \code{interactionTerm}. Specifies which term in \code{baseModel} the spatial smooth will interact with.  If \code{NULL} no interaction term is fitted.
#'    \code{cv.opts} Used if \code{fitnessMeasure = cv.gamMRSea}.  See above for specification.
#'
#'
#' @return
#' The spline paramater object that is returned as part of the model object now contains a list in the first element (previously reserved for the spatial component).  This list contains the objects required for the SALSA2D fitting process:
#'
#' \item{knotDist}{Matrix of knot to knot distances (k x k).  May be Euclidean or geodesic distances. Must be square and the same dimensions as \code{nrows(na.omit(knotgrid))}.  Created using \code{\link{makeDists}}.}
#' \item{radii}{Sequence of range parameters for the CReSS basis from local (small) to global (large).  Determines the range of the influence of each knot.}
#' \item{dist}{ Matrix of distances between data locations and knot locations (n x k). May be Euclidean or geodesic distances. Euclidean distances created using \code{\link{makeDists}}.}
#' \item{datacoords}{Coordinates of the data locations}
#' \item{response}{Vector of response data for the modelling process}
#' \item{knotgrid}{Grid of legal knot locations.}
#' \item{minKnots}{Minimum number of knots to be tried.}
#' \item{maxKnots}{Maximum number of knots to be tried.}
#' \item{gap}{Minimum gap between knots (in unit of measurement of \code{datacoords})}
#' \item{radiusIndices}{Vector of length startKnots identifying which radii (\code{splineParams[[1]]$radii}) will be used for each knot location (\code{splineParams[[1]]$knotPos})}
#' \item{knotPos}{Index of knot locations. The index identifies which knots (i.e. which rows) from \code{knotgrid} were selected by SALSA}
#'
#'
#' @examples
#' # load data
#' data(ns.data.re)
#' # load prediction data
#' data(ns.predict.data.re)
#' # load knot grid data
#' data(knotgrid.ns)
#'
#' splineParams<-makesplineParams(data=ns.data.re, varlist=c('observationhour'))
#'
#' #set some input info for SALSA
#' ns.data.re$response<- ns.data.re$birds
#'
#' # make distance matrices for datatoknots and knottoknots
#' distMats<-makeDists(cbind(ns.data.re$x.pos, ns.data.re$y.pos), na.omit(knotgrid.ns))
#'
#' # set initial model without the spatial term
#' # (so all other non-spline terms)
#' initialModel<- glm(response ~ as.factor(floodebb) + as.factor(impact) + offset(log(area)),
#'                    family='quasipoisson', data=ns.data.re)
#'
#' # make parameter set for running salsa2d
#' # I have chosen a gap parameter of 1000 (in metres) to speed up the process.
#' # Note that this means there cannot be two knots within 1000m of each other.
#'
#' salsa2dlist<-list(fitnessMeasure = 'QICb', knotgrid = na.omit(knotgrid.ns),
#'                   startKnots=6, minKnots=4, maxKnots=20, gap=1000,
#'                   interactionTerm="as.factor(impact)")
#'
#' salsa2dOutput_k6<-runSALSA2D(initialModel, salsa2dlist, d2k=distMats$dataDist,
#'                             k2k=distMats$knotDist, splineParams=splineParams)
#'
#'@author Lindesay Scott-Hayward (University of St Andrews), Cameron Walker (University of Auckland)
#'
#' @export
#'

runSALSA2Dmn<-function(model, salsa2dlist, d2k, k2k, datain, splineParams=NULL, chooserad=FALSE, panels=NULL, suppress.printout=FALSE, tol=0, plot=FALSE, basis='gaussian', initialise=TRUE, initialKnots=NULL, initialKnPos=NULL, hdetest=FALSE){

  if(class(model)[1]=='glm'){
    data<-model$data
  }
  if(class(model)[1]=='gamMRSea'){
    data<-model$data
    panels=model$panels
  }
  if(class(model)[1]=='lm'){
    data<-model$model
  }
  if(class(model)[1]=='vglmMRSea'){
    data <- model@data
    panels <- model@panels
  }
  if(class(model)[1]=='vglm'){
    data <- datain
  }
  
  if(isS4(model)){
    setClass("vglmMRSea", contains=c("vglm"), slots=c(varshortnames="character", panels="ANY", splineParams="list", data="data.frame", cvfolds="numeric", interactionterm="ANY")) -> vglmMRSea
    model <- as(model, "vglmMRSea")
    attributes(model@misc$formula)$.Environment<-environment()
    model@data <- data
    model<-make.vglmMRSea(model, vglmMRSea=TRUE)
    if(class(model)[1]!='vglmMRSea'){model<-make.vglmMRSea(model, vglmMRSea=TRUE)}
  } else {
    attributes(model$formula)$.Environment<-environment()
    if(class(model)[1]!='gamMRSea'){model<-make.gamMRSea(model, gamMRSea=TRUE)}
  }

  # check for response variable
  if (!isS4(model)){
    if(is.null(data$response)) stop('data does not contain response column')
  } else {
    if (dim(model@y)[2]==1) {
      if(is.null(data$response)) stop('data does not contain response column')
    } else {
      print('data is aggregated response is more than one column')
    }
  }

  # check for duplicates in knotgrid
  if(length(which(duplicated(salsa2dlist$knotgrid)==T))>0) stop ('knotgrid has duplicated locations in it. Please remove.')
  
  # check for use of name "dists" in data
  if("dists" %in% names(data)) stop("data must not contain column called 'dists'")
  
  
  #set input 2D input data
  if(is.null(data$x.pos)){ stop('no x.pos in data frame; rename coordinates')}
  explData<- cbind(data$x.pos, data$y.pos)
  #specify the full grid (including NAs where knots cannot go)
  knotgrid<- salsa2dlist$knotgrid
  #this sets the index of grid positions
  #grid<-expand.grid(1:salsa2dlist$knotdim[1], 1:salsa2dlist$knotdim[2])
  #gridResp<-salsa2dlist$knotgrid[,1]
  
  print(basis)
  
  if (!is.null(salsa2dlist$noradii)){
    norad <- salsa2dlist$noradii
  } else {
    norad <- 10
  }
  
  if (is.null(salsa2dlist$radin)) {
    r_seq<-getRadiiChoices(numberofradii = norad, distMatrix = d2k, basis)
  } else {
    r_seq<-getRadiiChoices(numberofradii = norad, distMatrix = d2k, basis, salsa2dlist$radin)
  }
  
  if(chooserad==FALSE){
    if(length(r_seq)>1){
      radii<- r_seq[round(length(r_seq)/2)]
    }else{
      radii<- r_seq[1]
    }
  }else{
    radii <- r_seq
  }
  winHalfWidth = 0
  
  interactionTerm<-salsa2dlist$interactionTerm
  
  if(is.null(salsa2dlist$cv.opts$cv.gamMRSea.seed)){salsa2dlist$cv.opts$cv.gamMRSea.seed<-357}
  seed.in<-salsa2dlist$cv.opts$cv.gamMRSea.seed
  
  if(is.null(salsa2dlist$cv.opts$K)){salsa2dlist$cv.opts$K<-10}
  if(is.null(salsa2dlist$cv.opts$cost)){salsa2dlist$cv.opts$cost<-function(y, yhat) mean((y - yhat)^2)}
  
  if(!is.null(panels)){
    if(length(unique(panels))!=nrow(data)){
      if (isS4(model)) {
        if(is.null(model@cvfolds)){
          model@cvfolds<-getCVids(data, folds=salsa2dlist$cv.opts$K, block=panels, seed=seed.in)  
        }
      } else {
        if(is.null(model$cvfolds)){
          model$cvfolds<-getCVids(data, folds=salsa2dlist$cv.opts$K, block=panels, seed=seed.in)  
        }
      }
    }
  }

  if(is.null(salsa2dlist$max.iter)){
    maxIterations<-10
  }else{
    maxIterations<-salsa2dlist$max.iter  
  }
  
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # ~~~~~~~~~~~~ SET UP ~~~~~~~~~~~~~~~~~
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if (isS4(model)){
    splineParams<-model@splineParams
    #number of covariates with spline terms
    if(length(splineParams)==0){
      splineParams<-list(2)
    }
  } else {
    splineParams<-model$splineParams
    #number of covariates with spline terms
    if(is.null(splineParams)){
      splineParams<-list(2)
    }
  }
  
  splineParams[[1]]=list(13) #2D Metadata
  splineParams[[1]][[1]]= NULL                        #starting knot positions
  splineParams[[1]][['knotDist']]= k2k
  splineParams[[1]][['dist']]= d2k
  splineParams[[1]][[4]]= NULL                        #starting radius indices
  #splineParams[[1]][['gridResp']]= gridResp
  #splineParams[[1]][['grid']]= grid
  if (!isS4(model)) {
    splineParams[[1]][['response']]= data$response
  } else {
    if (dim(model@y)[2] > 1) {
      splineParams[[1]][['response']]= model@y
    } else {
      splineParams[[1]][['response']]= data$response
    }
  }
  splineParams[[1]][['knotgrid']]= salsa2dlist$knotgrid
  splineParams[[1]][['datacoords']]= explData
  splineParams[[1]][['radii']]= radii
  splineParams[[1]][['minKnots']]= salsa2dlist$minKnots
  splineParams[[1]][['maxKnots']]= salsa2dlist$maxKnots
  if(is.null(salsa2dlist$gap)){
    splineParams[[1]][['gap']]= 0
  }else{
    splineParams[[1]][['gap']]= salsa2dlist$gap
  }
  splineParams[[1]][[14]]= NULL                       #this will be invInd
  
  if (isS4(model)) {
    model@splineParams<-splineParams
  } else {
    model$splineParams<-splineParams
  }
  
  if(dim(k2k)[2]==salsa2dlist$minKnots & dim(k2k)[2]==salsa2dlist$maxKnots & dim(k2k)[2]==salsa2dlist$startKnots){stop('Min, Max and Start knots all identical and equal to the total number of valid knots\n Please add more valid knot locations (knotgrid) or reduce min/max/start')}
  
  if(dim(k2k)[2]<salsa2dlist$minKnots | dim(k2k)[2]<salsa2dlist$startKnots){stop('Starting number of knots or min knots more than number of valid knot locations in knotgrid')}
  
  if (!isS4(model)) {
    if(salsa2dlist$fitnessMeasure=='BIC' & model$family$family=='quasipoisson' ){stop('Please use fitness Measure appropriate for quasi family, e.g. QICb')}
  }
  
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # ~~~~~~~~~~~~~~~~~~~~ 2D SALSA RUN ~~~~~~~~~~~~~~~~~~~~~~~
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if(suppress.printout){
    sink(file='salsa2d.log')
  }
  
  baseModel1D <- model
  baseModel <- baseModel1D

  output<-return.reg.spline.fit.2d(splineParams, startKnots=salsa2dlist$startKnots, winHalfWidth,fitnessMeasure=salsa2dlist$fitnessMeasure, maxIterations=maxIterations, tol=tol, baseModel=baseModel, radiusIndices=NULL, initialise=initialise,  initialKnots=initialKnots, initialaR=initialKnPos, interactionTerm=interactionTerm, knot.seed=10,suppress.printout, plot=plot, cv.opts = salsa2dlist$cv.opts, basis, hdetest=hdetest)
  
  baseModel<- output$out.lm

  #   if(length(output$models)==0){
  #     output$aR<- output$invInd[output$aR]
  #   }
  if(chooserad==FALSE){
    if(length(output$models)>0){
      modRes<- c()
      for(m in 1:length(output$models)){
        modelNo<- m
        knotPosition<-output$models[[m]][[1]]
        rIs<- output$models[[m]][[2]]
        r<- output$models[[m]][[3]]
        fitScore<- output$models[[m]][[4]]
        modRes<- rbind(modRes, data.frame(modelNo, knotPosition, rIs, fitScore))
      }
      
      modRes<-modRes[order(modRes$fitScore),]
      bestModNo<- unique(modRes$modelNo[which(modRes$fitScore==min(modRes$fitScore))])[1]
      
      a<-sum(as.vector(output$aR) - as.vector(unlist(output$models[[bestModNo]][1])))
      if(a!=0) break
      
      #output$aR<- output$models[[bestModNo]][[1]]
    }
    
    # use initialise step to change radii
    radii = r_seq
    # x <- as.vector(splineParams[[1]]$grid[,1])
    # y <- as.vector(splineParams[[1]]$grid[,2])
    # xvals <- max(x)
    # yvals <- max(y)
    
    if(length(r_seq)>1){
      radiusIndices<- rep(round(length(r_seq)/2), (length(output$aR)))
    }else{
      radiusIndices<- rep(1, length(output$aR))
    }
    initDisp<-getDispersion(baseModel)
    output_radii<- initialise.measures_2d(k2k, maxIterations=maxIterations, salsa2dlist$gap, radii, d2k, explData, splineParams[[1]]$startKnots, knotgrid, splineParams[[1]]$response, baseModel, radiusIndices=radiusIndices, initialise=F, initialKnots=salsa2dlist$knotgrid[output$aR,], initialaR=output$aR, fitnessMeasure=salsa2dlist$fitnessMeasure, interactionTerm=interactionTerm, data=data, knot.seed=10, initDisp, cv.opts=salsa2dlist$cv.opts, basis, hdetest)
    
    splineParams[[1]]$radii= radii
    splineParams[[1]][['knotPos']]= output_radii$aR
    TwoDModelsfirstStage <- output_radii$models
    splineParams[[1]][['radiusIndices']]= output_radii$radiusIndices
    splineParams[[1]][['invInd']] = output_radii$invInd
    modelFit = output_radii$BIC
    aRout<- list(aR1=output$aR, aR2=output_radii$aR)
    
    baseModel<-output_radii$out.lm
  }else{
    splineParams[[1]]$radii= radii
    splineParams[[1]][['knotPos']]= output$aR
    TwoDModelsfirstStage <- output$models
    splineParams[[1]][['radiusIndices']]= output$radiusIndices
    #splineParams[[1]][['invInd']] = output$invInd
    modelFit = output$outputFS[2]
    aRout = output$aR
  }
  
  # dists<-splineParams[[1]]$dist
  # aR<-splineParams[[1]]$invInd[splineParams[[1]]$knotPos]
  # radiusIndices<-splineParams[[1]]$radiusIndices
  # radii<-splineParams[[1]]$radii
  #class(baseModel)<-c('gamMRSea', class(baseModel))
  if (isS4(baseModel)) {
    dataname<-languageEl(model@call, which='data')
    baseModel@varshortnames<-model@varshortnames
    if (!is.null(panels)) {
      baseModel@panels<-panels
    }
    if (!is.null(interactionTerm)){
      baseModel@interactionterm<-interactionTerm
    }
  } else {
    dataname<-languageEl(model$call, which='data')
    baseModel$varshortnames<-model$varshortnames
    baseModel$panels<-panels
    baseModel$interactionterm<-interactionTerm
  }
  
  eval(parse(text=paste(substitute(dataname),"<-data", sep="" )))
  print(paste("update(baseModel, .~., data=", substitute(dataname),")", sep=""))
  baseModel<-eval(parse(text=paste("update(baseModel, .~., data=", substitute(dataname),")", sep="")))
  
  if (isS4(baseModel)) {
    attributes(baseModel@misc$formula)$.Environment<-globalenv()
    #save.image(paste("salsa2D_k", splineParams[[1]]$startKnots, ".RData", sep=''))
    if(class(model)[1]!='vglmMRSea') {
      baseModel<-make.vglmMRSea(baseModel, vglmMRSea=TRUE)
    }
  } else {
    attributes(baseModel$formula)$.Environment<-globalenv()
    #save.image(paste("salsa2D_k", splineParams[[1]]$startKnots, ".RData", sep=''))
    
    baseModel<-make.gamMRSea(baseModel, gamMRSea=TRUE)
  }

  if(suppress.printout){
    sink()
  }
  
  if (isS4(baseModel)){
    # test for huack donner effect
    hde_test_res <- hdeff(baseModel)
    if (sum(hde_test_res) > 0) {
      print("Warning Hauck Donner effect present standard errors should not be relied upon")  
      warning("Warning Hauck Donner effect present standard errors should not be relied upon")
    }  
  }
  
  print("end")
  return(list(bestModel=baseModel, splineParams=splineParams, fitStat=modelFit, aR=aRout))
}

