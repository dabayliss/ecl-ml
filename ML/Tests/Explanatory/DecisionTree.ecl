IMPORT * FROM ML;
IMPORT ML.Mat;

indepRecord := RECORD
	Types.t_FieldNumber outlook;
	Types.t_FieldNumber temperature;
	Types.t_FieldNumber humidity;
	Types.t_FieldNumber windy;
END;

indepRec_id := RECORD
	Types.t_RecordId    id := 0;
	indepRecord;
END;

depRecord := RECORD
	Types.t_FieldNumber play;
END;

depRec_id := RECORD
	Types.t_RecordId    id := 0;
	depRecord;
END;

indep_Data := DATASET([
{0,0,1,0},
{0,0,1,1},
{1,0,1,0},
{2,1,1,0},
{2,2,0,0},
{2,2,0,1},
{1,2,0,1},
{0,1,1,0},
{0,2,0,0},
{2,1,0,0},
{0,1,0,1},
{1,1,1,1},
{1,0,0,0},
{2,1,1,1}],
indepRecord);
pr_indep:= PROJECT(indep_data, TRANSFORM(indepRec_id, SELF.id := COUNTER,SELF:=LEFT));
ToField(pr_indep, attrib);
indep := ML.Discretize.ByRounding(attrib);
dep_data := DATASET([0,0,1,1,1,0,1,0,1,1,1,1,1,0], depRecord);
pr_dep:= PROJECT(dep_data, TRANSFORM(depRec_id, SELF.id := COUNTER,SELF:=LEFT));
ToField(pr_dep, class);
dep := ML.Discretize.ByRounding(class);

trainer:= Classify.DecisionTree(Classify.split_Algorithm.GiniImpurity);
model:= trainer.LearnD(Indep, Dep);
OUTPUT(model, NAMED('Model_NumericField'));
OUTPUT(SORT(trainer.Model(model), level, node_id), NAMED('Decision_Tree_Model'));
results:= trainer.ClassifyD(Indep, model);
results1:= Classify.Compare(Dep, results);
OUTPUT(results1.Raw, NAMED('Raw'));
OUTPUT(results1.CrossAssignments, NAMED('CrossAssignments'));
OUTPUT(results1.RecallByClass, NAMED('RecallByClass'));
OUTPUT(results1.PrecisionByClass, NAMED('PrecisionByClass'));
OUTPUT(SORT(results1.FP_Rate_ByClass, classifier, class), NAMED('FP_Rate_ByClass'));
OUTPUT(results1.Accuracy, NAMED('Accuracy'));