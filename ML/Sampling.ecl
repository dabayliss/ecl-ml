IMPORT * FROM ML;
IMPORT * FROM ML.Types;
IMPORT ML.Mat;
IMPORT ML.Mat.Vec AS Vec;
//	The purpose of this module is to implement Sampling methods
//	used to generate samples from an original dataset.

EXPORT Sampling := MODULE
	SHARED g_Method := ENUM(Zeroing, Randomizing);
	SHARED t_Index := UNSIGNED4;
	EXPORT idListRec := RECORD
		t_RecordID id;
		t_RecordID oldId;
	END;
	EXPORT idListGroupRec := RECORD(idListRec)
		UNSIGNED gNum := 0;
	END;
	SHARED idFoldRec := RECORD
		t_FieldNumber fold;
		t_RecordID id;
	END;
	SHARED NumericField CreateIdRecs(NumericField L, INTEGER C, INTEGER origSize, t_Discrete method = g_Method.Zeroing) := TRANSFORM
		SELF.id := c;
		SELF.number := 0;
		SELF.value := IF(method = g_Method.Zeroing, 0, RANDOM()%origSize + 1);
	END;	
	SHARED GenerateIdList(Types.t_Count origSize, Types.t_Discrete pctSize = 100, t_RecordID baseId = 0) := FUNCTION
		RETURN PROJECT(Vec.From(origSize * pctSize DIV 100),TRANSFORM(idListRec, SELF.id:=LEFT.x + baseId, SELF.oldid := RANDOM()%origSize + 1));
	END;
	SHARED dsRecordRnd := RECORD(NumericField)
		Types.t_FieldNumber rnd:= 0;	
	END;
	SHARED dsRecordRnd AddRandom(NumericField l) :=TRANSFORM
		SELF.rnd := RANDOM();
		SELF := l;
	END;
	SHARED NumericField GetRecords(NumericField l, idListRec r) := TRANSFORM
		SELF.id := r.id;
		SELF.number := l.number;
		SELF.value := l.value;
	END;
	SHARED dsDiscRecRnd := RECORD(DiscreteField)
		Types.t_FieldNumber rnd:= 0;	
	END;
// Used for sampling with replacement.
// Generates a list of N x origSize size,
// each new record maps to the original dataset id's and has a gNum group identifier.
// In order to get the complete dataset JOIN with original dataset is needed.
	EXPORT GenerateNSampleList(t_Index N, t_RecordID origSize) := FUNCTION
		seed := DATASET([{0,0,0}], idListGroupRec);
		PerCluster := ROUNDUP(N*origSize/CLUSTERSIZE);
		idListGroupRec addOffsetId(idListGroupRec L, t_Index c) := TRANSFORM
			SELF.id := (c-1)*PerCluster ;
			SELF.oldid:= 0;
		END;
		// Create and distribute one seed per node
		one_per_node := DISTRIBUTE(NORMALIZE(seed, CLUSTERSIZE, addOffsetId(LEFT, COUNTER)), id DIV PerCluster);
		idListGroupRec fillRec(idListGroupRec L, UNSIGNED4 c) := TRANSFORM
			SELF.id := l.id + c;
			SELF.oldId := RANDOM()%origSize + 1;
			SELF.gNum  := (l.id + c -1) DIV origSize + 1;
		END;
		// Generate records on each node
		// Filter extra nodes generated: (PerCluster * CLUSTERSIZE >= N*origSize) 
		m := NORMALIZE(one_per_node, PerCluster, fillRec(LEFT,COUNTER))(gNum <= N);
		RETURN m;
	END;
	
//	Method used to return results from various sampling methods.
//	Receives a dataset with a list of Ids and the original dataset.
//	Generates a subsample and returns the Id list, the sample generated and the original dataset. 
//
	EXPORT GeneratedData(DATASET(idListRec) dsIdList, DATASET(NumericField) origData) := MODULE
		EXPORT genIdList:= dsIdList;
		EXPORT origDataset := origData;
		jList := JOIN(origData, dsIdList, LEFT.id = RIGHT.oldId, GetRecords(LEFT, RIGHT), LOOKUP, MANY);
		EXPORT genSubSample:= SORT(jList, id, number);
	END;
	
// 	Returns a random sample without replacement from the original dataset.
//	The instances are picked randomly one by one without replacement (an instance can be picked only once)
//	until the desired size is reached. Maximun size is the original one.
// 		originalData	: original dataset
// 		pctSize				: [OPTIONAL] size of the sample expressed as a percentaje of original dataset, default value is 100
//		baseId				: [OPTIONAL] Id offset, allows results to have different Id ranges
//
	EXPORT RndSampleWithoutReplace(DATASET(NumericField) originalData, t_Discrete pctSize = 100, t_RecordID baseId = 0) := FUNCTION
		numIdx 	:= MIN(originalData, number);
		dsIds 	:= originalData(number = numIdx);
		origSize := COUNT(dsIds);
		dRnd := PROJECT(dsIds, AddRandom(LEFT));
		dRndSorted := SORT(dRnd, rnd);
		sampleSize := MIN(100, ROUND(origSize*pctSize/100));
		ds_raw := CHOOSEN(dRndSorted, sampleSize);
		ds_ids := PROJECT(ds_raw, TRANSFORM(idListRec, SELF.id := baseId + COUNTER, SELF.oldId := LEFT.id));
		RETURN GeneratedData(ds_ids, originalData);
	END;
	
// 	Returns a random sample with replacement from the original dataset.
//	The instances are picked randomly one by one with replacement (an instance can be picked more than once)
//	until until the desired size is reached. It is possible to return datasets larger than original.
// 		originalData	: original discretized dataset
// 		pctSize      	: [OPTIONAL] size of the sample expressed as a percentaje of original dataset, default value is 100  
//		baseId				: [OPTIONAL] Id offset, allows results to have different Id ranges, default value is 0
//
	EXPORT RndSampleWithReplace(DATASET(NumericField) originalData, t_Discrete pctSize = 100, t_RecordID baseId = 0) := FUNCTION
		numIdx 	:= MIN(originalData, number);
		dsIds 	:= originalData(number = numIdx);
		origSize := COUNT(dsIds);
		ds_ids:= GenerateIdList(origSize, pctSize, baseId);
		RETURN GeneratedData(ds_ids, originalData);
	END;
	
// 	Returns a stratified sample with replacement from the original dataset.
//	The data is divided in subgroups based on a field of interest(class) before sampling,
//	then subgroups are sampled with replacement (an instance can be picked more than once)
//	until the desired size is reached. It is possible to return datasets larger than original.
//	The resultant recordset mantains the original field of interest(class) distribution.
// 		originalData	: original discretized dataset
// 		pctSize				: [OPTIONAL] size of the sample expressed as a percentaje of original dataset, default value is 100
//		baseId				: [OPTIONAL] Id offset, allows results to have different Id ranges, default value is 0
//		fieldClass		: [OPTIONAL] index of field that contains the class identifier (stratum), 
//									  default value 0 means that class column is the last original dataset's column  
//
	EXPORT StratSampleWithReplace(DATASET(NumericField) originalData, t_Discrete pctSize = 100, t_RecordID baseId = 0, t_FieldNumber fieldClass = 0) := FUNCTION
		classIdx 	:= IF(fieldClass = 0, MAX(originalData, number), fieldClass);
		dsClass 	:= SORT(originalData(number=classIdx), Value);
		classSup	:= TABLE(dsClass,{value, pSize:=ROUND(COUNT(GROUP)*pctSize/100); Support := COUNT(GROUP), Offset:=0}, value, FEW);
		tRec:= RECORDOF(classSup);
		tRec T(tRec l, tRec r):= TRANSFORM
			SELF.Offset := l.pSize + l.Offset;
			SELF:=r;
		END;
		// There are very few class values. Used when generating dsGenId to calculate final id (storedd in number),
		// instead of an aditional PROJECT(ds_ids) to add 'id' 
		classDist := ITERATE(classSup, T(LEFT,RIGHT));	
		dsGenId		:= NORMALIZE(classDist, LEFT.pSize, TRANSFORM(NumericField, SELF.id:= 1 + RANDOM()%LEFT.Support, SELF.number:= COUNTER + LEFT.Offset, SELF:=LEFT));
		Utils.mac_SequenceInField(dsClass, Value, Number, dsMapId); 
		ds_ids		:= JOIN(dsMapId, dsGenId, LEFT.value = RIGHT.value AND LEFT.number = RIGHT.id, TRANSFORM(idListRec, SELF.id := RIGHT.number + baseId, SELF.oldid := LEFT.id), LOOKUP, MANY);
		RETURN GeneratedData(ds_ids, originalData);
	END;

//	Folds a dependent dataset in N partitions, ready to run multi-classifier learn.
//	Receives a dependent dataset (class field) and returns it divided into partitions
//	by overwriting the 'number' field with the resultant partition number,
//	all partitions having same class distribution as original dataset.
// 		originalData : original discretized Dependent dataset
// 		num_part      : number of partitions
//
	EXPORT DiscreteDepNFolds(DATASET(DiscreteField) originalData, t_FieldNumber num_part) := FUNCTION
		dRnd := PROJECT(originalData, TRANSFORM(dsDiscRecRnd, SELF.rnd := RANDOM(), SELF:= LEFT));
		dRndSorted := SORT(dRnd, value, rnd);
		ds_part := PROJECT(dRndSorted, TRANSFORM(DiscreteField, SELF.number := COUNTER%num_part + 1, SELF:= LEFT));
		RETURN SORT(ds_part, number);
	END;

//	Folds a dataset in N partitions.
//	Returns a fold-id allocation list and a method to get a particular Fold with optional baseId offset.
//	all partitions having same distribution as original dataset over field indicated.
// 		originalData	: original discretized Dependent dataset
// 		num_part      : number of partitions
//		fieldDistrib	: [OPTIONAL] field having distribution desired, default 0 indicate last field
//
	EXPORT NFold(DATASET(NumericField) originalData, t_Discrete num_part, Types.t_FieldNumber fieldDistrib = 0) := MODULE
		distribIdx 	:= if(fieldDistrib = 0, max(originalData, number), fieldDistrib);
		dRnd := PROJECT(originalData(number = distribIdx), AddRandom(LEFT));	
		dRndSorted := SORT(dRnd,value,rnd);
		SHARED ds_parts := PROJECT(dRndSorted, TRANSFORM(idFoldRec, SELF.Fold := COUNTER%num_part + 1, SELF:= LEFT));
		EXPORT NFoldList:= SORT(ds_parts, id);
		EXPORT FoldNDS(t_Discrete num_fold, t_RecordID baseId = 0) := FUNCTION
			ds_ids := ds_parts(fold = num_fold);
			RETURN JOIN(originalData, ds_ids,LEFT.id = RIGHT.id, TRANSFORM(NumericField, SELF.id:= LEFT.id + baseId, SELF:=LEFT), LOOKUP); 			
		END;
	END;

// Builds N Cross-Validation Train/Test Datasets. 
// See: http://en.wikipedia.org/wiki/Cross-validation_(statistics)#K-fold_cross-validation
//	Returns a fold-id allocation list, all partitions having same distribution as original dataset over field indicated.
//  and methods (FoldNTrainDS, FoldNTestDS) to get a particular Train or Tests Fold with optional baseId offset.
// 		originalData	: original discretized dataset
// 		num_part      : number of folds
//		fieldDistrib	: [OPTIONAL] field having distribution desired, default 0 indicate last field
//
	EXPORT NFoldCross(DATASET(NumericField) originalData, t_Discrete num_part, t_FieldNumber fieldDistrib = 0) := MODULE
		SHARED distribIdx 	:= IF(fieldDistrib = 0, MAX(originalData, number), fieldDistrib);
		SHARED ds_parts := NFold(originalData, num_part, distribIdx).NFoldList;
		EXPORT NFoldList:= ds_parts;
		EXPORT FoldNTrainDS (t_Discrete num_fold, t_RecordID baseId = 0) := FUNCTION
			ds_ids := ds_parts(fold!= num_fold);
			RETURN JOIN(originalData, ds_ids,LEFT.id = RIGHT.id, TRANSFORM(NumericField, SELF.id:= LEFT.id + baseId, SELF:=LEFT), LOOKUP); 
		END;
		EXPORT FoldNTestDS (t_Discrete num_fold, t_RecordID baseId = 0) := FUNCTION
			ds_ids := ds_parts(fold = num_fold);
			RETURN JOIN(originalData, ds_ids,LEFT.id = RIGHT.id, TRANSFORM(NumericField, SELF.id:= LEFT.id + baseId, SELF:=LEFT), LOOKUP); 
		END;
	END;
END;