#' DepInfeR for inferring sample-specific protein dependencies
#' 
#' DepInfeR integrates two experimentally accessible input data matrices: 
#' the drug sensitivity profiles of cancer cell lines or primary tumors 
#' ex-vivo (X), and the drug affinities of a set of proteins (Y), to infer 
#' a matrix of molecular protein dependencies of the cancers (ß). 
#' DepInfeR deconvolutes the protein inhibition effect on the viability 
#' phenotype by using regularized multivariate linear regression. 
#' It assigns a “dependence coefficient” to each protein and each sample, 
#' and therefore could be used to gain a causal and accurate understanding of 
#' functional consequences of genomic aberrations in a heterogeneous disease, 
#' as well as to guide the choice of pharmacological intervention for a specific 
#' cancer type, sub-type, or an individual patient. For more information, 
#' please read out preprint on bioRxiv: \url{https://doi.org/10.1101/2022.01.11.475864}. 
#'
#' The main functions are:
#'
#' \itemize{
#' \item \code{\link{runLASSORegression}} - perform inference of target importance
#' \item \code{\link{processTarget}} - pre-process drug-protein affinity dataset
#' }
#' 
#' For detailed information on usage, see the package vignette, by typing
#' \code{vignette("DepInfeR")}.
#' 
#' All software-related questions should be posted to the Bioconductor Support Site:
#' 
#' \url{https://support.bioconductor.org}
#'
#' The code can be viewed at the GitHub repository.
#' \url{https://github.com/Huber-group-EMBL/DepInfeR}
#' 
#' @references
#'
#' Batzilla, A. and Lu, J. et al. (2022)
#' Inferring tumor-specific cancer dependencies through integrating ex-vivo 
#' drug response assays and drug-protein profiling.
#' \url{https://www.biorxiv.org/content/10.1101/2022.01.11.475864v1}
#'
#' @author Alina Batzilla, Junyan Lu
#' 
#' @docType package
#' @name DepInfeR-package
#' @aliases DepInfeR-package
#' @keywords package
NULL



#' Function for pre-processing drug-protein affinity dataset
#'
#' This function is used to preprocess the drug-protein affinity dataset
#' including the following steps:
#' - log-transform kd values (KdAsInput = TRUE)
#' - arctan-transform log(kd) values (KdAsInput = TRUE)
#' - check target similarity and remove highly correlated proteins
#' (removeCorrelated = TRUE)
#' - specify targets that should be kept in the matrix (keepTargets = NULL)
#'
#' All steps within this function are optional depending on input data.
#' The transformation steps should be performed
#' if the affinity matrix consists of kd values.
#' If there are highly correlated features within the affinity matrix,
#' they can be removed using the provided function.
#'
#' @param targetsMat Drug-protein affinity matrix with kd values (or optionally 
#' other affinity measurement values at roughly normal distribution). Each row is
#' a drug and each column is a sample (cell line or tumor sample).
#' @param KdAsInput A boolean value indicating whether the drug-protein
#' affinity matrix contains kd values which should be log- and arctan-transformed.
#' The default value is TRUE.
#' @param removeCorrelated A boolean value indicating whether highly
#' correlated proteins should be summarized in target groups. 
#' The default value is TRUE.
#' @param keepTargets  A character variable that specifies important proteins
#' that should be retained in the matrix.
#' @param cutoff A Cosine similarity cutoff value for clustering proteins 
#' into one target group. The value should be between 0 and 1.
#' @export
#' @return A list of two elements: 1)\code{targetMatrix} Pre-processed drug-protein
#' affinity matrix; 2)\code{targetCluster}, a list that contains the targets
#' show high correlations with each other.
#'
#' @examples
#' data(targetMatrix)
#' processTarget(targetsMat = targetMatrix, KdAsInput = TRUE , removeCorrelated = TRUE)
#'

processTarget <- function(targetsMat, KdAsInput = TRUE, removeCorrelated = TRUE,
                          keepTargets = NULL, cutoff=0.8) {
    
    #check arguments
    stopifnot(is.matrix(targetsMat))
    stopifnot(is.logical(KdAsInput))
    stopifnot(is.logical(removeCorrelated))
    stopifnot(is.character(keepTargets) | is.null(keepTargets))
    stopifnot(is.numeric(cutoff) & cutoff <=1 & cutoff >=0)
    
    if (KdAsInput) {
        targetsMat <- -log10(targetsMat) #log transform kd values
        targetsMat[is.na(targetsMat)] <- -10 #fill NA values with a very small pKd value (-10)
        arcTrans <- function(x,b = 2, g = 1) {     #define arctan function
            y <- (atan((x + b) * g) + pi/2)/pi
        }

        targetsMat <- arcTrans(targetsMat, b = 2, g = 3) #apply arctan transformation
    }

    if (removeCorrelated) {
        cosineSimi <- function(x) {
            x%*%t(x)/(sqrt(rowSums(x^2) %*% t(rowSums(x^2))))
        }
        simiMat <- cosineSimi(t(targetsMat)) #save similarity matrix
        #remove highly correlated features
        #allow manually specify important proteins to keep
        #sort target matrix per target importance to keep most important proteins in the dataset
        targetOrder <- colnames(targetsMat)[order(colSums(-targetsMat))]

        if (!is.null(keepTargets)) { #manually specify some important proteins
            targetOrder <- c(keepTargets, targetOrder[!targetOrder %in% keepTargets])
        }

        targetsMat <- targetsMat[,targetOrder]
        res <- removeCorrelatedTargets(targetsMat, cutoff = cutoff,
                                       cluster_method = "ward.D2")
        resTarMat <- res$reduced
        mapReduce_kd <- res$mapReduce
        ProcessTargetResults <- list(targetMatrix = resTarMat,
                                     targetCluster = mapReduce_kd)

    } else {
        ProcessTargetResults <- list(targetMatrix = targetsMat,
                                     targetCluster = NULL)
    }
    return(ProcessTargetResults)
}



#' Main function for running LASSO regression to calculate protein dependence coefficient
#' 
#' This function performs multivariate linear regression with LASSO penalty and 
#' cross-validation to infer per-sample protein dependence coefficients. 
#' Please refer to the package vignette for more detailed information about this function.
#' For the mathematical model behind this function, 
#' please refer to our preprint on bioRxiv: \url{https://doi.org/10.1101/2022.01.11.475864}.
#' 
#' @param TargetMatrix Pre-processed drug-protein affinity matrix. 
#' Each row is a drug and each column is a protein target.
#' @param ResponseMatrix Pre-processed drug-response viability matrix. 
#' Each row is a drug and each column is a sample (cell line or tumor sample).  
#' @param repeats A integer variable specifying the number of regression repeats.
#' The default value is 100. A higher number can result in better stability but 
#' also takes longer time.  
#' @param BPPARAM The BiocParallel back-end. If not specified, the default 
#' \code{MulticoreParam} will be used. 
#' @export
#' @import glmnet stats BiocParallel
#' @importFrom matrixStats rowMedians
#' 
#' @return A list of 6 elements: 
#' \item{coefMat}{A matrix containing the inferred protein dependency coefficient matrix.
#'  Each row is a protein and each column is a sample.}
#' \item{freqMat}{A matrix containing the selection frequency a protein (row) for each sample (column).}
#' \item{lambdaList}{A vector containing the lambda values selected for all repeated runs.}
#' \item{varExplain.all}{A vector containing the R2 (variance explained) values for all repeated runs.}
#' \item{inputX}{A copy of the input drug-protein affinity matrix.}
#' \item{inputY}{A copy of the input drug-repsonse viability matrix.}
#' 
#' @examples
#' data(responseInput) #load drug response matrix
#' data(targetInput) #load drug-target affinity matrix
#' runLASSORegression(TargetMatrix = targetInput, ResponseMatrix = responseInput, repeats = 5)
#'
runLASSORegression <- function(TargetMatrix, ResponseMatrix, repeats = 100,
                               BPPARAM = bpparam()) {
    
  #check arguments
  stopifnot(is.matrix(TargetMatrix))
  stopifnot(is.matrix(ResponseMatrix))
  stopifnot(is.numeric(repeats) & repeats == round(repeats))
  
  #function for multi-target LASSO with repeated cross-validation
  runGlm.multi <- function(i, X, y, folds=3, lambda = "lambda.min",
                                standardize = FALSE) {
    res <- cv.glmnet(X, y, family = "mgaussian",
                     nfolds = folds, alpha = 1,
                     standardize = standardize)
    res
  }
  
  allResults <- bplapply(seq(repeats), runGlm.multi, 
                         TargetMatrix, ResponseMatrix, 
                         BPPARAM = BPPARAM)

  
  #Run function for processing glm results
  processGlm(allResults, TargetMatrix, ResponseMatrix)
  
}
