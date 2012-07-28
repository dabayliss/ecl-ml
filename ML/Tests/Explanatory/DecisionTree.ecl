IMPORT * FROM ML;
IMPORT ML.Mat;
IMPORT ML.Tests.Explanatory as TE;
/*
//This is the tennis-weather dataset transformed to discrete number values.
weatherRecord := RECORD
	Types.t_RecordID id;
	Types.t_FieldNumber outlook;
	Types.t_FieldNumber temperature;
	Types.t_FieldNumber humidity;
	Types.t_FieldNumber windy;
	Types.t_FieldNumber play;
END;

weather_Data := DATASET([
{1,0,0,1,0,0},
{2,0,0,1,1,0},
{3,1,0,1,0,1},
{4,2,1,1,0,1},
{5,2,2,0,0,1},
{6,2,2,0,1,0},
{7,1,2,0,1,1},
{8,0,1,1,0,0},
{9,0,2,0,0,1},
{10,2,1,0,0,1},
{11,0,1,0,1,1},
{12,1,1,1,1,1},
{13,1,0,0,0,1},
{14,2,1,1,1,0}],
weatherRecord);
indep_data:= TABLE(weather_Data,{id, outlook, temperature, humidity, windy});
dep_data:= TABLE(weather_Data,{id, play});
indep_test:= indep_data
dep_test:= dep_data
*/
//You can use the tennis-weather dataset (above) instead and You will find same models for both decision tree clasiffiers.
//Using MONKS dataset you will find different results between the classifiers.
//TE.MonkDS.Train_Data;
indep_data:= TABLE(TE.MonkDS.Train_Data,{id, a1, a2, a3, a4, a5, a6});
dep_data:= TABLE(TE.MonkDS.Train_Data,{id, class});
ToField(indep_data, pr_indep);
indep := ML.Discretize.ByRounding(pr_indep);
ToField(dep_data, pr_dep);
dep := ML.Discretize.ByRounding(pr_dep);

//TE.MonkDS.Test_Data;;
indep_test:= TABLE(TE.MonkDS.Test_Data,{id, a1, a2, a3, a4, a5, a6});
dep_test:= TABLE(TE.MonkDS.Test_Data,{id, class});
ToField(indep_data, t_indep);
indep_t := ML.Discretize.ByRounding(t_indep);
ToField(dep_data, t_dep);
dep_t := ML.Discretize.ByRounding(t_dep);

//Training the classifiers using split_Algorithm 1. GiniImpurity and 2. InfoGainRatio
trainer1:= Classify.DecisionTree(Classify.split_Algorithm.GiniImpurity);
model1:= trainer1.LearnD(Indep, Dep);
trainer2:= Classify.DecisionTree(Classify.split_Algorithm.InfoGainRatio);
model2:= trainer2.LearnD(Indep, Dep);
OUTPUT(model1, NAMED('Model1'));
OUTPUT(SORT(trainer1.Model(model1), level, node_id), NAMED('DecTree_1'), ALL);
OUTPUT(model2, NAMED('Model2'));
OUTPUT(SORT(trainer2.Model(model2), level, node_id), NAMED('DecTree_2'), ALL);

//Classifying independent test data and comparing with dependent test data 
results1:= trainer1.ClassifyD(indep_t, model1);
results11:= Classify.Compare(dep_t, results1);
results2:= trainer2.ClassifyD(indep_t, model2);
results21:= Classify.Compare(dep_t, results2);

//Showing Results
OUTPUT(results11.CrossAssignments, NAMED('CrossAssig1'));
OUTPUT(results11.RecallByClass, NAMED('RecallByClass1'));
OUTPUT(results11.PrecisionByClass, NAMED('PrecByClass1'));
OUTPUT(SORT(results11.FP_Rate_ByClass, classifier, class), NAMED('FPR_ByClass1'));
OUTPUT(results11.Accuracy, NAMED('Accur1'));
OUTPUT(results21.CrossAssignments, NAMED('CrossAssig2'));
OUTPUT(results21.RecallByClass, NAMED('RecallByClass2'));
OUTPUT(results21.PrecisionByClass, NAMED('PrecByClass2'));
OUTPUT(SORT(results21.FP_Rate_ByClass, classifier, class), NAMED('FPR_ByClass2'));
OUTPUT(results21.Accuracy, NAMED('Accur2'));