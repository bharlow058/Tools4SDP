## Loading libraries

library(foreign)
library(cvTools)

library(randomForest)
library(rpart)
library(e1071)
library(nnet)

## Informational columns

infoCols = c(
  "methodName",
  "commitId"
)

## Uninteresting columns to be discardeds

discardCols = c(
  "ADDING_ATTRIBUTE_MODIFIABILITY",
  "ADDING_CLASS_DERIVABILITY",
  "ADDITIONAL_CLASS",
  "ADDITIONAL_FUNCTIONALITY",
  "ADDITIONAL_OBJECT_STATE",
  "ATTRIBUTE_RENAMING",
  "ATTRIBUTE_TYPE_CHANGE",
  "CLASS_RENAMING",
  "COMMENT_DELETE",
  "COMMENT_INSERT",
  "COMMENT_MOVE",
  "COMMENT_UPDATE",
  "DOC_DELETE",
  "DOC_INSERT",
  "DOC_UPDATE",
  "PARENT_CLASS_CHANGE",
  "PARENT_CLASS_DELETE",
  "PARENT_CLASS_INSERT",
  "PARENT_INTERFACE_CHANGE",
  "PARENT_INTERFACE_DELETE",
  "PARENT_INTERFACE_INSERT",
  "REMOVED_CLASS",
  "REMOVED_FUNCTIONALITY",
  "REMOVED_OBJECT_STATE",
  "REMOVING_ATTRIBUTE_MODIFIABILITY",
  "REMOVING_CLASS_DERIVABILITY",
  "UNCLASSIFIED_CHANGE"
)

## Change columns to be used as raw features

rawChangeCols = c(
  "ALTERNATIVE_PART_DELETE",
  "ALTERNATIVE_PART_INSERT",
  "CONDITION_EXPRESSION_CHANGE",
  "STATEMENT_DELETE",
  "STATEMENT_INSERT",
  "STATEMENT_ORDERING_CHANGE",
  "STATEMENT_PARENT_CHANGE",
  "STATEMENT_UPDATE"
)

## Parameter change columns

paramChangeCols = c(
  "PARAMETER_DELETE",
  "PARAMETER_INSERT",
  "PARAMETER_ORDERING_CHANGE",
  "PARAMETER_RENAMING",
  "PARAMETER_TYPE_CHANGE"
)

## Other method header change columns

headerChangeCols = c(
  "ADDING_METHOD_OVERRIDABILITY",
  "DECREASING_ACCESSIBILITY_CHANGE",
  "INCREASING_ACCESSIBILITY_CHANGE",
  "METHOD_RENAMING",
  "REMOVING_METHOD_OVERRIDABILITY",
  "RETURN_TYPE_CHANGE",
  "RETURN_TYPE_DELETE",
  "RETURN_TYPE_INSERT"
)

## Additional features

additionalFeatureCols = c(
  "numCommits",
  "numAuthors",
  "avgChanges",
  "avgEntities",
  "avgAuthorCommits",
  "avgAuthorChanges",
  "avgChangeRatio",
  "changeGini"
)

## Bug-proneness columns

bugPronenessCols = c(
  "linBugProneness0.0",
  "geomBugProneness0.7",
  "weightBugProneness"
)

## Function for reading data, preprocessing features & filtering instances

readTrainData = function(filePath) {
  data = read.arff(filePath)
  
  bugProneness = data[bugPronenessCols]
  rawChanges = data[rawChangeCols]
  paramsChanges = apply(data[paramChangeCols], 1, sum)
  headerChanges = apply(data[headerChangeCols], 1, sum)
  additionalFeatures = data[additionalFeatureCols[additionalFeatureCols %in% colnames(data)]]
  
  trainData = cbind(rawChanges, additionalFeatures, bugProneness,
                    paramsChange = paramsChanges, headerChange = headerChanges)
  trainData[complete.cases(trainData),]
}

## Functions for performing cross-validation of various models

performCV = function(trainData, classColName, ...) {
  x = trainData[, !names(trainData) %in% bugPronenessCols]
  y = trainData[, classColName]
  trainData = cbind(x, class=y)
  
  forestCV = suppressWarnings(cvFit(randomForest, class~., trainData, ...))$cv
  treeCV = suppressWarnings(cvFit(rpart, class~., trainData, ...))$cv
  svmCV = suppressWarnings(cvFit(svm, class~., trainData, ...))$cv
  nnetCV = suppressWarnings(cvFit(nnet, x=x, y=y, args=c(size=10, linout=T, trace=F), ...))$cv
  
  c(forest=forestCV, tree=treeCV, svm=svmCV, nnet=nnetCV)
}

performAllCV = function(trainData, K=20, R=10, seed=12345, ...) {
  sapply(bugPronenessCols, function(col) performCV(trainData, classColName = col, K=K, ...))
}

## Read data extracted from repositories

commonsLang = readTrainData("commons-lang.arff")
guava = readTrainData("guava.arff")
hibernate = readTrainData("hibernate.arff")
jetty = readTrainData("jetty.arff")
jgit = readTrainData("jgit.arff")
junit = readTrainData("junit.arff")
log4j = readTrainData("log4j.arff")
maven = readTrainData("maven.arff")
mockito = readTrainData("mockito.arff")
spring = readTrainData("spring.arff")

## Perform some experiments

commonsLangCV = performAllCV(commonsLang)
guavaCV = performAllCV(guava)
hibernateCV = performAllCV(hibernate)
jettyCV = performAllCV(jetty)
jgitCV = performAllCV(jgit)
junitCV = performAllCV(junit)
log4jCV = performAllCV(log4j)
mavenCV = performAllCV(maven)
mockitoCV = performAllCV(mockito)
springCV = performAllCV(spring)

allResults = list(commonsLangCV, guavaCV, hibernateCV, jettyCV, jgitCV, junitCV,
                  log4jCV, mavenCV, mockitoCV, springCV)
avgResults = apply(simplify2array(allResults), c(1,2), mean)
