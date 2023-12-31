% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/depInfeR.R
\name{runLASSORegression}
\alias{runLASSORegression}
\title{Main function for running LASSO regression to calculate protein dependence coefficient}
\usage{
runLASSORegression(
  TargetMatrix,
  ResponseMatrix,
  repeats = 100,
  BPPARAM = bpparam()
)
}
\arguments{
\item{TargetMatrix}{Pre-processed drug-protein affinity matrix. 
Each row is a drug and each column is a protein target.}

\item{ResponseMatrix}{Pre-processed drug-response viability matrix. 
Each row is a drug and each column is a sample (cell line or tumor sample).}

\item{repeats}{A integer variable specifying the number of regression repeats.
The default value is 100. A higher number can result in better stability but 
also takes longer time.}

\item{BPPARAM}{The BiocParallel back-end. If not specified, the default 
\code{MulticoreParam} will be used.}
}
\value{
A list of 6 elements: 
\item{coefMat}{A matrix containing the inferred protein dependency coefficient matrix.
 Each row is a protein and each column is a sample.}
\item{freqMat}{A matrix containing the selection frequency a protein (row) for each sample (column).}
\item{lambdaList}{A vector containing the lambda values selected for all repeated runs.}
\item{varExplain.all}{A vector containing the R2 (variance explained) values for all repeated runs.}
\item{inputX}{A copy of the input drug-protein affinity matrix.}
\item{inputY}{A copy of the input drug-repsonse viability matrix.}
}
\description{
This function performs multivariate linear regression with LASSO penalty and 
cross-validation to infer per-sample protein dependence coefficients. 
Please refer to the package vignette for more detailed information about this function.
For the mathematical model behind this function, 
please refer to our preprint on bioRxiv: \url{https://doi.org/10.1101/2022.01.11.475864}.
}
\examples{
data(responseInput) #load drug response matrix
data(targetInput) #load drug-target affinity matrix
runLASSORegression(TargetMatrix = targetInput, ResponseMatrix = responseInput, repeats = 5)

}
