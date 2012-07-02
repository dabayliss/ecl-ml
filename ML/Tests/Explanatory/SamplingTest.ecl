IMPORT * from ML;
IMPORT ML.Mat;
BayesModule := ML.Classify.NaiveBayes;

ds :=  ML.Tests.Explanatory.samplingDS;
ML.AppendID(ds, id, dOrig);
OUTPUT(dOrig, NAMED('OrigSeq'));
ML.ToField(dOrig,dMatrix);
D2 := ML.Discretize.ByRounding(dMatrix);
OUTPUT(D2, NAMED('OrigMatrix'));
indep	:= D2(Number<=3);
dep		:= D2(Number=4);
OUTPUT(indep, NAMED('Indep'));
OUTPUT(dep, NAMED('Dep'));

// RndSampleWithOutReplace Example
// generating a 25% sized random subsample from original,
// instances can only be picked once
s1:= Sampling.RndSampleWithOutReplace(dMatrix, 25,1000);
OUTPUT(s1.genIdList, NAMED('SmplNoRepIdList'), ALL);
OUTPUT(s1.genSubSample, NAMED('SmplNoRepGenSample'), ALL);

// RndSampleWithReplace Example
// generating a 150% sized random sample from original 
// instances can be picked more than once
s2:= Sampling.RndSampleWithReplace(dMatrix, 150,2000);
OUTPUT(s2.genIdList, NAMED('SmplRepIdList'), ALL);
OUTPUT(s2.genSubSample, NAMED('SmplRepGenSample'), ALL);

// StratSampleWithReplace Example
// generating a 120% sized stratified sample from original 
// instances can be picked more than once, having original class distribution
s3:= Sampling.StratSampleWithReplace(dMatrix, 120, 3000);
OUTPUT(s3.genIdList, NAMED('StratSmplIdList'), ALL);
s3Dist:= s3.genSubSample;
OUTPUT(s3Dist, NAMED('StratSmplGenSample'), ALL);
OUTPUT(s3Dist(number=4), NAMED('StratSmplDist'), ALL);