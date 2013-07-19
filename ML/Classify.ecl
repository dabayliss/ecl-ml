IMPORT ML;
IMPORT * FROM $;
IMPORT $.Mat;
IMPORT * FROM ML.Types;

/*
		The object of the classify module is to generate a classifier.
    A classifier is an 'equation' or 'algorithm' that allows the 'class' of an object to be imputed based upon other properties
    of an object.
*/

EXPORT Classify := MODULE

SHARED l_result := RECORD(Types.DiscreteField)
  REAL8 conf;  // Confidence - high is good
	REAL8 closest_conf;
  END;

SHARED l_model := RECORD
  Types.t_RecordId    id := 0; 			// A record-id - allows a model to have an ordered sequence of results
	Types.t_FieldNumber number;				// A reference to a feature (or field) in the independants
	Types.t_Discrete    class_number; // The field number of the dependant variable
	REAL8 w;
END;

// Function to compute the efficacy of a given classification process
// Expects the dependents (classification tags deemed to be true)
// Computeds - classification tags created by the classifier
EXPORT Compare(DATASET(Types.DiscreteField) Dep,DATASET(l_result) Computed) := MODULE
	DiffRec := RECORD
		Types.t_FieldNumber classifier;  // The classifier in question (value of 'number' on outcome data)
		Types.t_Discrete  c_actual;      // The value of c provided
		Types.t_Discrete  c_modeled;		 // The value produced by the classifier
		Types.t_FieldReal score;         // Score allocated by classifier
		Types.t_FieldReal score_delta;   // Difference to next best
		BOOLEAN           sole_result;   // Did the classifier only have one option
	END;
	DiffRec  notediff(Computed le,Dep ri) := TRANSFORM
	  SELF.c_actual := ri.value;
		SELF.c_modeled := le.value;
		SELF.score := le.conf;
		SELF.score_delta := IF ( le.closest_conf>0, le.closest_conf-le.conf,0 );
		SELF.sole_result := le.closest_conf=0;
		SELF.classifier := ri.number;
	END;
	SHARED J := JOIN(Computed,Dep,LEFT.id=RIGHT.id AND LEFT.number=RIGHT.number,notediff(LEFT,RIGHT));
	// Shows which classes were modeled as which classes
	EXPORT Raw := TABLE(J,{classifier,c_actual,c_modeled,score,score_delta,sole_result,Cnt := COUNT(GROUP)},classifier,c_actual,c_modeled,score,score_delta,sole_result,MERGE);
	// Building the Confusion Matrix
	SHARED ConfMatrix_Rec := RECORD
		Types.t_FieldNumber classifier;	// The classifier in question (value of 'number' on outcome data)
		Types.t_Discrete c_actual;			// The value of c provided
		Types.t_Discrete c_modeled;			// The value produced by the classifier
		Types.t_FieldNumber Cnt:=0;			// Number of occurences
	END;
	SHARED class_cnt := TABLE(Dep,{classifier:= number, c_actual:= value, Cnt:= COUNT(GROUP)},number, value, FEW); // Looking for class values
	ConfMatrix_Rec form_cfmx(class_cnt le, class_cnt ri) := TRANSFORM
	  SELF.classifier := le.classifier;
		SELF.c_actual:= le.c_actual;
		SELF.c_modeled:= ri.c_actual;
	END;
	SHARED cfmx := JOIN(class_cnt, class_cnt, LEFT.classifier = RIGHT.classifier, form_cfmx(LEFT, RIGHT)); // Initialzing the Confusion Matrix with 0 counts
	SHARED cross_raw := TABLE(J,{classifier,c_actual,c_modeled,Cnt := COUNT(GROUP)},classifier,c_actual,c_modeled,FEW); // Counting ocurrences
	ConfMatrix_Rec form_confmatrix(ConfMatrix_Rec le, cross_raw ri) := TRANSFORM
		SELF.Cnt	:= ri.Cnt;
		SELF 			:= le;
	END;
//CrossAssignments, it returns information about actual and predicted classifications done by a classifier
//                  also known as Confusion Matrix
	EXPORT CrossAssignments := JOIN(cfmx, cross_raw,
														LEFT.classifier = RIGHT.classifier AND LEFT.c_actual = RIGHT.c_actual AND LEFT.c_modeled = RIGHT.c_modeled,
														form_confmatrix(LEFT,RIGHT),
														LEFT OUTER, LOOKUP);
//RecallByClass, it returns the percentage of instances belonging to a class that was correctly classified,
//               also know as True positive rate and sensivity, TP/(TP+FN).
	EXPORT RecallByClass := SORT(TABLE(J,{classifier,c_actual, tp_rate := AVE(GROUP,IF(c_actual=c_modeled,100,0))},classifier,c_actual,FEW), classifier, c_actual);
//PrecisionByClass, returns the percentage of instances classified as a class that really belong to this class: TP /(TP + FP).
	EXPORT PrecisionByClass := SORT(TABLE(J,{classifier,c_modeled, Precision := AVE(GROUP,IF(c_actual=c_modeled,100,0))},classifier,c_modeled,FEW), classifier, c_modeled);
//FP_Rate_ByClass, it returns the percentage of instances not belonging to a class that were incorrectly classified as this class,
//                 also known as False Positive rate FP / (FP + TN).
	FalseRate_rec := RECORD
		Types.t_FieldNumber classifier;
		Types.t_Discrete class;
		Types.t_FieldReal fp_rate;
	END;
	FalseRate_rec FalseRate(class_cnt le):= TRANSFORM
		wrong_modeled:=COUNT(J(c_modeled=le.c_actual AND c_actual<>le.c_actual AND classifier = le.classifier)); // Incorrectly classified as actual class
		not_class:= COUNT(J(c_actual<>le.c_actual AND classifier = le.classifier)); // Not belonging to the actual class
		SELF.classifier:= le.classifier;
		SELF.class:= le.c_actual;
		SELF.fp_rate:= wrong_modeled/not_class;
	END;
	EXPORT FP_Rate_ByClass := PROJECT(class_cnt, FalseRate(LEFT));
// Accuracy, it returns the percentage of instances correctly classified (total, without class distinction)
	EXPORT HeadLine := TABLE(J,{classifier, Accuracy := AVE(GROUP,IF(c_actual=c_modeled,100,0))},classifier,FEW);
	EXPORT Accuracy := HeadLine;
END;
/*
	The purpose of this module is to provide a default interface to provide access to any of the 
  classifiers
*/
	EXPORT Default := MODULE,VIRTUAL
		EXPORT Base := 1000; // ID Base - all ids should be higher than this
		// Premise - two models can be combined by concatenating (in terms of ID number) the under-base and over-base parts
		SHARED CombineModels(DATASET(Types.NumericField) sofar,DATASET(Types.NumericField) new) := FUNCTION
			UBaseHigh := MAX(sofar(id<Base),id);
			High := IF(EXISTS(sofar),MAX(sofar,id),Base);
			UB := PROJECT(new(id<Base),TRANSFORM(Types.NumericField,SELF.id := LEFT.id+UBaseHigh,SELF := LEFT));
			UO := PROJECT(new(id>=Base),TRANSFORM(Types.NumericField,SELF.id := LEFT.id+High-Base,SELF := LEFT));
			RETURN sofar+UB+UO;
		END;
	  // Learn from continuous data
	  EXPORT LearnC(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := DATASET([],Types.NumericField); // All classifiers serialized to numeric field format
	  // Learn from discrete data - worst case - convert to continuous
	  EXPORT LearnD(DATASET(Types.DiscreteField) Indep,DATASET(Types.DiscreteField) Dep) := LearnC(PROJECT(Indep,Types.NumericField),Dep);
	  // Learn from continuous data - using a prebuilt model
	  EXPORT ClassifyC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := DATASET([],l_result);
	  // Classify discrete data - using a prebuilt model
	  EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := ClassifyC(PROJECT(Indep,Types.NumericField),mod);
		EXPORT TestD(DATASET(Types.DiscreteField) Indep,DATASET(Types.DiscreteField) Dep) := FUNCTION
		  a := LearnD(Indep,Dep);
			res := ClassifyD(Indep,a);
			RETURN Compare(Dep,res);
		END;
		EXPORT TestC(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := FUNCTION
		  a := LearnC(Indep,Dep);
			res := ClassifyC(Indep,a);
			RETURN Compare(Dep,res);
		END;
		EXPORT LearnDConcat(DATASET(Types.DiscreteField) Indep,DATASET(Types.DiscreteField) Dep, LearnD fnc) := FUNCTION
		  // Call fnc once for each dependency; concatenate the results
			// First get all the dependant numbers
			dn := DEDUP(Dep,number,ALL);
			Types.NumericField loopBody(DATASET(Types.NumericField) sf,UNSIGNED c) := FUNCTION
			  RETURN CombineModels(sf,fnc(Indep,Dep(number=dn[c].number)));
			END;
			RETURN LOOP(DATASET([],Types.NumericField),COUNT(dn),loopBody(ROWS(LEFT),COUNTER));
		END;
		EXPORT LearnCConcat(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep, LearnC fnc) := FUNCTION
		  // Call fnc once for each dependency; concatenate the results
			// First get all the dependant numbers
			dn := DEDUP(Dep,number,ALL);
			Types.NumericField loopBody(DATASET(Types.NumericField) sf,UNSIGNED c) := FUNCTION
			  RETURN CombineModels(sf,fnc(Indep,Dep(number=dn[c].number)));
			END;
			RETURN LOOP(DATASET([],Types.NumericField),COUNT(dn),loopBody(ROWS(LEFT),COUNTER));
		END;
	END;

  EXPORT NaiveBayes := MODULE(DEFAULT)
		SHARED SampleCorrection := 1;
		SHARED LogScale(REAL P) := -LOG(P)/LOG(2);

/* Naive Bayes Classification 
	 This method can support producing classification results for multiple classifiers at once
	 Note the presumption that the result (a weight for each value of each field) can fit in memory at once
*/

		SHARED BayesResult := RECORD(l_model)
			Types.t_discrete c; 						 // Independant value
			Types.t_discrete f := 0;				 // Dependant result
//			REAL8 P;                         // Either P(F|C) or P(C) if number = 0. Stored in -Log2(P) - so small is good :)
			Types.t_Count Support;           // Number of cases
		END;

/*
  The inputs to the BuildNaiveBayes are:
  a) A dataset of discretized independant variables
  b) A dataset of class results (these must match in ID the discretized independant variables).
     Some routines can produce multiple classifiers at once; if so these are distinguished using the NUMBER field of cl
*/
	  EXPORT LearnD(DATASET(Types.DiscreteField) Indep,DATASET(Types.DiscreteField) Dep) := FUNCTION
			dd := Indep;
			cl := Dep;
			Triple := RECORD
				Types.t_Discrete c;
				Types.t_Discrete f;
				Types.t_FieldNumber number;
				Types.t_FieldNumber class_number;
			END;
			Triple form(dd le,cl ri) := TRANSFORM
				SELF.c := ri.value;
				SELF.f := le.value;
				SELF.number := le.number;
				SELF.class_number := ri.number;
			END;
			Vals := JOIN(dd,cl,LEFT.id=RIGHT.id,form(LEFT,RIGHT));
			AggregatedTriple := RECORD
				Vals.c;
				Vals.f;
				Vals.number;
				Vals.class_number;
				Types.t_Count support := COUNT(GROUP);
			END;
			// This is the raw table - how many of each value 'f' for each field 'number' appear for each value 'c' of each classifier 'class_number'
			Cnts := TABLE(Vals,AggregatedTriple,c,f,number,class_number,FEW);
			// Compute P(C)
			CTots := TABLE(cl,{value,number,Support := COUNT(GROUP)},value,number,FEW);
			CLTots := TABLE(CTots,{number,TSupport := SUM(GROUP,Support), GC := COUNT(GROUP)},number,FEW);
			P_C_Rec := RECORD
				Types.t_Discrete c;            // The value within the class
				Types.t_Discrete class_number; // Used when multiple classifiers being produced at once
				Types.t_FieldReal support;     // Used to store total number of C
				REAL8 w;                       // P(C)
			END;
			// Apply Laplace Estimator to P(C) in order to be consistent with attributes' probability
			P_C_Rec pct(CTots le,CLTots ri) := TRANSFORM
				SELF.c := le.value;
				SELF.class_number := ri.number;
				SELF.support := le.Support + SampleCorrection;
				SELF.w := (le.Support + SampleCorrection) / (ri.TSupport + ri.GC*SampleCorrection);
			END;
			PC := JOIN(CTots,CLTots,LEFT.number=RIGHT.number,pct(LEFT,RIGHT),FEW);
			// Computing Attributes' probability
			AttribValue_Rec := RECORD
				Cnts.class_number; 	// Used when multiple classifiers being produced at once
				Cnts.number;				// A reference to a feature (or field) in the independants
				Cnts.f;				 			// Independant value
				Types.t_Count support := 0;
			END;
			// Generating feature domain per feature (class_number only used when multiple classifiers being produced at once)
			AttValues	:= TABLE(Cnts, AttribValue_Rec, class_number, number, f, FEW);
			AttCnts 	:= TABLE(AttValues, {class_number, number, ocurrence:= COUNT(GROUP)},class_number, number, FEW); // Summarize	
			AttrValue_per_Class_Rec := RECORD
				Types.t_Discrete c;
				AttValues.f;
				AttValues.number;
				AttValues.class_number;
				AttValues.support;
			END;
			// Generating class x feature domain, initial support = 0
			AttrValue_per_Class_Rec form_cl_attr(AttValues le, CTots ri):= TRANSFORM
				SELF.c:= ri.value;
				SELF:= le;
			END;
			ATots:= JOIN(AttValues, CTots, LEFT.class_number = RIGHT.number, form_cl_attr(LEFT, RIGHT), MANY LOOKUP, FEW);
			// Counting feature value ocurrence per class x feature, remains 0 if combination not present in dataset
			ATots form_ACnts(ATots le, Cnts ri) := TRANSFORM
				SELF.support	:= ri.support;
				SELF 			:= le;
			END;
			ACnts := JOIN(ATots, Cnts, LEFT.c = RIGHT.c AND LEFT.f = RIGHT.f AND LEFT.number = RIGHT.number AND LEFT.class_number = RIGHT.class_number, 
														form_ACnts(LEFT,RIGHT),
														LEFT OUTER, LOOKUP);
			// Summarizing and getting value 'GC' to apply in Laplace Estimator
			TotalFs := TABLE(ACnts,{c,number,class_number,Types.t_Count Support := SUM(GROUP,Support),GC := COUNT(GROUP)},c,number,class_number,FEW);
			// Merge and Laplace Estimator
			F_Given_C_Rec := RECORD
				ACnts.c;
				ACnts.f;
				ACnts.number;
				ACnts.class_number;
				ACnts.support;
				REAL8 w;
			END;
			F_Given_C_Rec mp(ACnts le,TotalFs ri) := TRANSFORM
				SELF.support := le.Support+SampleCorrection;
				SELF.w := (le.Support+SampleCorrection) / (ri.Support+ri.GC*SampleCorrection);
				SELF := le;
			END;
			// Calculating final probabilties
			FC := JOIN(ACnts,TotalFs,LEFT.C = RIGHT.C AND LEFT.number=RIGHT.number AND LEFT.class_number=RIGHT.class_number,mp(LEFT,RIGHT),LOOKUP);
			Pret := PROJECT(FC,TRANSFORM(BayesResult,SELF := LEFT))+PROJECT(PC,TRANSFORM(BayesResult,SELF.number := 0,SELF:=LEFT));
			Pret1 := PROJECT(Pret,TRANSFORM(BayesResult,SELF.w := LogScale(LEFT.w),SELF.id := Base+COUNTER,SELF := LEFT));
			ToField(Pret1,o);
			RETURN o;
		END;
// Function to turn 'generic' classifier output into specific
// This will be the 'same' in every module - but not overridden - has unique return type
   EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
	   ML.FromField(mod,BayesResult,o);
		 RETURN o;
	 END;
// This function will take a pre-existing NaiveBayes model (mo) and score every row of a discretized dataset
// The output will have a row for every row of dd and a column for every class in the original training set
		EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
		   d := Indep;
			 mo := Model(mod);
  // Firstly we can just compute the support for each class from the bayes result
			dd := DISTRIBUTE(d,HASH(id)); // One of those rather nice embarassingly parallel activities
			Inter := RECORD
				Types.t_discrete c;
				Types.t_discrete class_number;
				Types.t_RecordId Id;
				REAL8  w;
			END;
			Inter note(dd le,mo ri) := TRANSFORM
				SELF.c := ri.c;
				SELF.class_number := ri.class_number;
				SELF.id := le.id;
				SELF.w := ri.w;
			END;
	// RHS is small so ,ALL join should work ok
	// Ignore the "explicitly distributed" compiler warning - the many lookup is preserving the distribution
			J := JOIN(dd,mo,LEFT.number=RIGHT.number AND LEFT.value=RIGHT.f,note(LEFT,RIGHT),MANY LOOKUP);
			InterCounted := RECORD
				J.c;
				J.class_number;
				J.id;
				REAL8 P := SUM(GROUP,J.W);
				Types.t_FieldNumber Missing := COUNT(GROUP); // not really missing just yet :)
			END;
			TSum := TABLE(J,InterCounted,c,class_number,id,LOCAL);
	// Now we have the sums for all the F present for each class we need to
	// a) Add in the P(C)
	// b) Suitably penalize any 'f' which simply were not present in the model
	// We start by counting how many not present ...
			FTots := TABLE(DD,{id,c := COUNT(GROUP)},id,LOCAL);
			InterCounted NoteMissing(TSum le,FTots ri) := TRANSFORM
				SELF.Missing := ri.c - le.Missing;
				SELF := le;
			END;
			MissingNoted := JOIN(Tsum,FTots,LEFT.id=RIGHT.id,NoteMissing(LEFT,RIGHT),LOOKUP);
			InterCounted NoteC(MissingNoted le,mo ri) := TRANSFORM
				SELF.P := le.P+ri.w+le.Missing*LogScale(SampleCorrection/ri.support);
				SELF := le;
			END;
			CNoted := JOIN(MissingNoted,mo(number=0),LEFT.c=RIGHT.c,NoteC(LEFT,RIGHT),LOOKUP);
			S := DEDUP(SORT(CNoted,Id,class_number,P,c,LOCAL),Id,class_number,LOCAL,KEEP(2));

			l_result tr(S le) := TRANSFORM
			  SELF.value := le.c; // Store the value of the classifier
				SELF.number := le.class_number; 
				SELF.Conf := le.p;
				SELF.closest_conf := 0;
				SELF.id := le.id;
			END;
			
			ST := PROJECT(S,tr(LEFT));
			l_result rem(ST le, ST ri) := TRANSFORM
				SELF.closest_conf := ri.conf;
				SELF := le;
			END;
			Ro := ROLLUP(ST,LEFT.id=RIGHT.id AND LEFT.number=RIGHT.number,rem(LEFT,RIGHT),LOCAL);
			RETURN Ro;
		END;
	END;

/*
	See: http://en.wikipedia.org/wiki/Perceptron
  The inputs to the BuildPerceptron are:
  a) A dataset of discretized independant variables
  b) A dataset of class results (these must match in ID the discretized independant variables).
  c) Passes; number of passes over the data to make during the learning process
  d) Alpha is the learning rate - higher numbers may learn quicker - but may not converge
  Note the perceptron presently assumes the class values are ordinal eg 4>3>2>1>0

	Output: A table of weights for each independant variable for each class. 
	Those weights with number=class_number give the error rate on the last pass of the data
*/

  EXPORT Perceptron(UNSIGNED Passes,REAL8 Alpha = 0.1) := MODULE(DEFAULT)
		SHARED Thresh := 0.5; // The threshold to apply for the cut-off function

	  EXPORT LearnD(DATASET(Types.DiscreteField) Indep,DATASET(Types.DiscreteField) Dep) := FUNCTION
			dd := Indep;
			cl := Dep;
			MaxFieldNumber := MAX(dd,number);
			FirstClassNo := MaxFieldNumber+1;
			clb := Utils.RebaseDiscrete(cl,FirstClassNo);
			LastClassNo := MAX(clb,number);
			all_fields := dd+clb;
	// Fields are ordered so that everything for a given input record is on one node
	// And so that records are encountered 'lowest first' and with the class variables coming later
			ready := SORT( DISTRIBUTE( all_fields, HASH(id) ), id, Number, LOCAL );
  // A weight record for our perceptron
			WR := RECORD
				REAL8 W := 0;
				Types.t_FieldNumber number; // The field this weight applies to - note field 0 will be the bias, class_number will be used for cumulative error
				Types.t_Discrete class_number;
			END;
			VR := RECORD
				Types.t_FieldNumber number;
				Types.t_Discrete    value;
			END;
	// This function exists to initialize the weights for the perceptron
			InitWeights := FUNCTION
				Classes := TABLE(clb,{number},number,FEW);
				WR again(Classes le,UNSIGNED C) := TRANSFORM
					SELF.number := IF( C > MaxFieldNumber, le.number, C ); // The > case sets up the cumulative error; rest are the field weights
					SELF.class_number := le.number;
				END;
				RETURN NORMALIZE(Classes,MaxFieldNumber+2,again(LEFT,COUNTER-1));
			END;

			AccumRec := RECORD
				DATASET(WR) Weights;
				DATASET(VR) ThisRecord;
				Types.t_RecordId Processed;
			END;
	// The learn step for a perceptrom
			Learn(DATASET(WR) le,DATASET(VR) ri,Types.t_FieldNumber fn,Types.t_Discrete va) := FUNCTION
				let := le(class_number=fn);
				letn := let(number<>fn);     // all of the regular weights
				lep := le(class_number<>fn); // Pass-thru
	  // Compute the 'predicted' value for this iteration as Sum WiXi
				iv := RECORD
					REAL8 val;
				END;
		// Compute the score components for each class for this record
				iv scor(le l,ri r) := TRANSFORM
					SELF.val := l.w*IF(r.number<>0,r.value,1);
				END;
				sc := JOIN(letn,ri,LEFT.number=RIGHT.number,scor(LEFT,RIGHT),LEFT OUTER);
				res := IF( SUM(sc,val) > Thresh, 1, 0 );
				err := va-res;
				let_e := PROJECT(let(number=fn),TRANSFORM(WR,SELF.w := LEFT.w+ABS(err), SELF:=LEFT)); // Build up the accumulative error
				delta := alpha*err; // The amount of 'learning' to do this step
		// Apply delta to regular weights
				WR add(WR le,VR ri) := TRANSFORM
					SELF.w := le.w+delta*IF(ri.number=0,1,ri.value); // Bias will not have matching RHS - so assume 1
					SELF := le;
				END;
				J := JOIN(letn,ri,LEFT.number=right.number,add(LEFT,RIGHT),LEFT OUTER);
				RETURN let_e+J+lep;
			END;
  // Zero out the error values
			WR Clean(DATASET(WR) w) := FUNCTION
				RETURN w(number<>class_number)+PROJECT(w(number=class_number),TRANSFORM(WR,SELF.w := 0, SELF := LEFT));
			END;
	// This function does one pass of the data learning into the weights
			WR Pass(DATASET(WR) we) := FUNCTION
		// This takes a record one by one and processes it
		// That may mean simply appending it to 'ThisRecord' - or it might mean performing a learning step
				AccumRec TakeRecord(ready le,AccumRec ri) := TRANSFORM
					BOOLEAN lrn := le.number >= FirstClassNo;
					BOOLEAN init := ~EXISTS(ri.Weights);
					SELF.Weights := MAP ( init => Clean(we), 
																~lrn => ri.Weights,
																Learn(ri.Weights,ri.ThisRecord,le.number,le.value) );
		// This is either an independant variable - in which case we append it
		// Or it is the last dependant variable - in which case we can throw the record away
		// Or it is one of the dependant variables - so keep the record for now
					SELF.ThisRecord := MAP ( ~lrn => ri.ThisRecord+ROW({le.number,le.value},VR),
																	le.number = LastClassNo => DATASET([],VR),
																	ri.ThisRecord);
					SELF.Processed := ri.Processed + IF( le.number = LastClassNo, 1, 0 );
				END;
		  // Effectively merges two perceptrons (generally 'learnt' on different nodes)
			// For the errors - simply add them
			// For the weights themselves perform a weighted mean (weighting by the number of records used to train)
				Blend(DATASET(WR) l,UNSIGNED lscale, DATASET(WR) r,UNSIGNED rscale) := FUNCTION
					lscaled := PROJECT(l(number<>class_number),TRANSFORM(WR,SELF.w := LEFT.w*lscale, SELF := LEFT));
					rscaled := PROJECT(r(number<>class_number),TRANSFORM(WR,SELF.w := LEFT.w*rscale, SELF := LEFT));
					unscaled := (l+r)(number=class_number);
					t := TABLE(lscaled+rscaled+unscaled,{number,class_number,w1 := SUM(GROUP,w)},number,class_number,FEW);
					RETURN PROJECT(t,TRANSFORM(WR,SELF.w := IF(LEFT.number=LEFT.class_number,LEFT.w1,LEFT.w1/(lscale+rscale)),SELF := LEFT));
				END;		
				AccumRec MergeP(AccumRec ri1,AccumRec ri2) := TRANSFORM
					SELF.ThisRecord := []; // Merging only valid across perceptrons learnt on complete records
					SELF.Processed := ri1.Processed+ri2.Processed;
					SELF.Weights := Blend(ri1.Weights,ri1.Processed,ri2.Weights,ri2.Processed);
				END;

				A := AGGREGATE(ready,AccumRec,TakeRecord(LEFT,RIGHT),MergeP(RIGHT1,RIGHT2))[1];
		// Now return the weights (and turn the error number into a ratio)
				RETURN A.Weights(class_number<>number)+PROJECT(A.Weights(class_number=number),TRANSFORM(WR,SELF.w := LEFT.w / A.Processed,SELF := LEFT));
			END;
			L := LOOP(InitWeights,Passes,PASS(ROWS(LEFT)));
			L1 := PROJECT(L,TRANSFORM(l_model,SELF.id := COUNTER+Base,SELF := LEFT));
			ML.ToField(L1,o);
			RETURN o;
		END;
    EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
	    ML.FromField(mod,l_model,o);
		  RETURN o;
	  END;
	  EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
		  mo := Model(mod);
			Ind := DISTRIBUTE(Indep,HASH(id));
			l_result note(Ind le,mo ri) := TRANSFORM
			  SELF.conf := le.value*ri.w;
				SELF.closest_conf := 0;
				SELF.number := ri.class_number;
				SELF.value := 0;
				SELF.id := le.id;
			END;
			// Compute the score for each component of the linear equation
			j := JOIN(Ind,mo,LEFT.number=RIGHT.number,note(LEFT,RIGHT),MANY LOOKUP); // MUST be lookup! Or distribution goes
			l_result ac(l_result le, l_result ri) := TRANSFORM
			  SELF.conf := le.conf+ri.conf;
			  SELF := le;
			END;
			// Rollup so there is one score for every id for every 'number' (original class_number)
			t := ROLLUP(SORT(j,id,number,LOCAL),LEFT.id=RIGHT.id AND LEFT.number=RIGHT.number,ac(LEFT,RIGHT),LOCAL);
			// Now we have to add on the 'constant' offset
			l_result add_c(l_result le,mo ri) := TRANSFORM
			  SELF.conf := le.conf+ri.w;
				SELF.value := IF(SELF.Conf>Thresh,1,0);
				SELF := le;
			END;
			t1 := JOIN(t,mo(number=0),LEFT.number=RIGHT.class_number,add_c(LEFT,RIGHT),LEFT OUTER);
			t2 := PROJECT(t1,TRANSFORM(l_Result,SELF.conf := ABS(LEFT.Conf-Thresh), SELF := LEFT));
			RETURN t2;
		END;
	END;

/*
	Logistic Regression implementation base on the iteratively-reweighted least squares (IRLS) algorithm:
  http://www.cs.cmu.edu/~ggordon/IRLS-example

	Logistic Regression module parameters:
	- Ridge: an optional ridge term used to ensure existance of Inv(X'*X) even if 
		some independent variables X are linearly dependent. In other words the Ridge parameter
		ensures that the matrix X'*X+mRidge is non-singular.
	- Epsilon: an optional parameter used to test convergence
	- MaxIter: an optional parameter that defines a maximum number of iterations

	The inputs to the Logis module are:
  a) A training dataset X of discretized independant variables
  b) A dataset of class results Y.

*/

EXPORT Logistic(REAL8 Ridge=0.00001, REAL8 Epsilon=0.000000001, UNSIGNED2 MaxIter=200) := MODULE(DEFAULT)
	Logis(DATASET(Types.NumericField) X,DATASET(Types.NumericField) Y) := MODULE
		SHARED mu_comp := ENUM ( Beta = 1,  Y = 2 );
		SHARED RebaseY := Utils.RebaseNumericField(Y);
		SHARED Y_Map := RebaseY.Mapping(1);
		Y_0 := RebaseY.ToNew(Y_Map);
		mY := Types.ToMatrix(Y_0);
		mX_0 := Types.ToMatrix(X);
		mX := Mat.InsertColumn(mX_0, 1, 1.0); // Insert X1=1 column 
	
		mXstats := Mat.Has(mX).Stats;
		mX_n := mXstats.XMax;
		mX_m := mXstats.YMax;

		mW := Mat.Vec.ToCol(Mat.Vec.From(mX_n,1.0),1);
		mRidge := Mat.Vec.ToDiag(Mat.Vec.From(mX_m,ridge));
		mBeta0 := Mat.Vec.ToCol(Mat.Vec.From(mX_m,0.0),1);	
		mBeta00 := Mat.MU.To(mBeta0, mu_comp.Beta);
		OldExpY_0 := Mat.Vec.ToCol(Mat.Vec.From(mX_n,-1.0),1); // -ones(size(mY))
		OldExpY_00 := Mat.MU.To(OldExpY_0, mu_comp.Y);

		Step(DATASET(Mat.Types.MUElement) BetaPlusY) := FUNCTION
			OldExpY := Mat.MU.From(BetaPlusY, mu_comp.Y);
			AdjY := Mat.Mul(mX, Mat.MU.From(BetaPlusY, mu_comp.Beta));
		// expy =  1./(1+exp(-adjy))
			ExpY := Mat.Each.Reciprocal(Mat.Each.Add(Mat.Each.Exp(Mat.Scale(AdjY, -1)),1));
		// deriv := expy .* (1-expy)
			Deriv := Mat.Each.Mul(expy,Mat.Each.Add(Mat.Scale(ExpY, -1),1));
		// wadjy := w .* (deriv .* adjy + (y-expy))
			W_AdjY := Mat.Each.Mul(mW,Mat.Add(Mat.Each.Mul(Deriv,AdjY),Mat.Sub(mY, ExpY)));
		// weights := spdiags(deriv .* w, 0, n, n)
			Weights := Mat.Vec.ToDiag(Mat.Vec.FromCol(Mat.Each.Mul(Deriv, mW),1));
		// mBeta := Inv(x' * weights * x + mRidge) * x' * wadjy
			mBeta :=  Mat.Mul(Mat.Mul(Mat.Inv(Mat.Add(Mat.Mul(Mat.Mul(Mat.Trans(mX), weights), mX), mRidge)), Mat.Trans(mX)), W_AdjY);
			err := SUM(Mat.Each.Abs(Mat.Sub(ExpY, OldExpY)),value);	
			RETURN IF(err < mX_n*Epsilon, BetaPlusY, Mat.MU.To(mBeta, mu_comp.Beta)+Mat.MU.To(ExpY, mu_comp.Y));
		END;

		SHARED BetaPair := LOOP(mBeta00+OldExpY_00, MaxIter, Step(ROWS(LEFT)));	
		BetaM := Mat.MU.From(BetaPair, mu_comp.Beta);
		rebasedBetaNF := RebaseY.ToOld(Types.FromMatrix(BetaM), Y_Map);
		BetaNF := Types.FromMatrix(Mat.Trans(Types.ToMatrix(rebasedBetaNF)));
	// convert Beta into NumericField dataset, and shift Number down by one to ensure the intercept Beta0 has id=0
		EXPORT Beta := PROJECT(BetaNF,TRANSFORM(Types.NumericField,SELF.Number := LEFT.Number-1;SELF:=LEFT;));
			Res := PROJECT(Beta,TRANSFORM(l_model,SELF.Id := COUNTER+Base,SELF.number := LEFT.number, SELF.class_number := LEFT.id, SELF.w := LEFT.value));
			ToField(Res,o);
		EXPORT Mod := o;
		modelY_M := Mat.MU.From(BetaPair, mu_comp.Y);
		modelY_NF := Types.FromMatrix(modelY_M);
		EXPORT modelY := RebaseY.ToOld(modelY_NF, Y_Map);
	END;
  EXPORT LearnCS(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := Logis(Indep,PROJECT(Dep,Types.NumericField)).mod;
	EXPORT LearnC(DATASET(Types.NumericField) Indep,DATASET(Types.DiscreteField) Dep) := LearnCConcat(Indep,Dep,LearnCS);
	EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
	  FromField(mod,l_model,o);
		RETURN o;
	END;
  EXPORT ClassifyC(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
	  mod0 := Model(mod);
		Beta0 := PROJECT(mod0,TRANSFORM(Types.NumericField,SELF.Number := LEFT.Number+1,SELF.id := LEFT.class_number, SELF.value := LEFT.w;SELF:=LEFT;));
	  mBeta := Types.ToMatrix(Beta0);
	  mX_0 := Types.ToMatrix(Indep);
		mXloc := Mat.InsertColumn(mX_0, 1, 1.0); // Insert X1=1 column 
		
		AdjY := $.Mat.Mul(mXloc, $.Mat.Trans(mBeta)) ;
		// expy =  1./(1+exp(-adjy))
		sigmoid := $.Mat.Each.Reciprocal($.Mat.Each.Add($.Mat.Each.Exp($.Mat.Scale(AdjY, -1)),1));
		// Now convert to classify return format
		l_result tr(sigmoid le) := TRANSFORM
		  SELF.value := IF ( le.value > 0.5,1,0);
		  SELF.id := le.x;
			SELF.number := le.y;
			SELF.conf := ABS(le.value-0.5);
			SELF.closest_conf := 0;
		END;
		RETURN PROJECT(sigmoid,tr(LEFT));
	END;
		
	END; // Logistic Module
	

/* From Wikipedia: 
http://en.wikipedia.org/wiki/Decision_tree_learning#General
"... Decision tree learning is a method commonly used in data mining.
The goal is to create a model that predicts the value of a target variable based on several input variables.
... A tree can be "learned" by splitting the source set into subsets based on an attribute value test. 
This process is repeated on each derived subset in a recursive manner called recursive partitioning. 
The recursion is completed when the subset at a node has all the same value of the target variable,
or when splitting no longer adds value to the predictions.
This process of top-down induction of decision trees (TDIDT) [1] is an example of a greedy algorithm,
and it is by far the most common strategy for learning decision trees from data, but it is not the only strategy."
The module can learn using different splitting algorithms, and return a model.
The Decision Tree (model) has the same structure independently of which split algorithm was used.
The model  is used to predict the class from new examples.
*/
	EXPORT DecisionTree := MODULE
		EXPORT model_Map :=	DATASET([{'id','ID'},{'node_id','1'},{'level','2'},{'number','3'},{'value','4'},{'new_node_id','5'}], {STRING orig_name; STRING assigned_name;});
		EXPORT STRING model_fields := 'node_id,level,number,value,new_node_id';	// need to use field map to call FromField later
		SHARED GenClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
			ML.FromField(mod, Trees.SplitF, nodes, model_Map);	// need to use model_Map previously build when Learning (ToField)
			leafs := nodes(new_node_id = 0);	// from final nodes
			splitData:= Trees.SplitInstances(nodes, Indep);
			l_result final_class(RECORDOF(splitData) l, RECORDOF(leafs) r ):= TRANSFORM
				SELF.id 		:= l.id;
				SELF.number	:= 1;
				SELF.value	:= r.value;
				SELF.conf				:= 0;		// added to fit in l_result, not used so far
				SELF.closest_conf:= 0;	// added to fit in l_result, not used so far
			END;
			RETURN JOIN(splitData, leafs, LEFT.new_node_id = RIGHT.node_id, final_class(LEFT, RIGHT), LOOKUP);
		END;
		// Function to turn 'generic' classifier output into specific
		EXPORT GenModel(DATASET(Types.NumericField) mod) := FUNCTION
			ML.FromField(mod,Trees.SplitF,o, model_Map);
			RETURN o;
		END;
/*	
		Decision Tree Learning using Gini Impurity-Based criterion
*/
		EXPORT GiniImpurityBased(INTEGER1 Depth=10, REAL Purity=1.0):= MODULE(DEFAULT)
			EXPORT LearnD(DATASET(Types.DiscreteField) Indep, DATASET(Types.DiscreteField) Dep) := FUNCTION
				nodes := ML.Trees.SplitsGiniImpurBased(Indep, Dep, Depth, Purity);
				AppendID(nodes, id, model);
				ToField(model, out_model, id, model_fields);
				RETURN out_model;
			END;
			EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
				RETURN GenClassifyD(Indep,mod);
			END;
			EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
				RETURN GenModel(mod);
			END;
		END;
/*
		Decision Tree using C4.5 Algorithm (Quinlan, 1987)
*/
		EXPORT C45(BOOLEAN Pruned= TRUE, INTEGER1 numFolds = 3, REAL z = 0.67449) := MODULE(DEFAULT)
			EXPORT LearnD(DATASET(Types.DiscreteField) Indep, DATASET(Types.DiscreteField) Dep) := FUNCTION
				nodes := IF(Pruned, Trees.SplitsIGR_Pruned(Indep, Dep, numFolds, z), Trees.SplitsInfoGainRatioBased(Indep, Dep));
				AppendID(nodes, id, model);
				ToField(model, out_model, id, model_fields);
				RETURN out_model;
			END;
			EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
				RETURN GenClassifyD(Indep,mod);
			END;
			EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
				RETURN GenModel(mod);
			END;
		END;
	END; // DecisionTree Module
	
	
/* From http://www.stat.berkeley.edu/~breiman/RandomForests/cc_home.htm#overview
   "... Random Forests grows many classification trees.
   To classify a new object from an input vector, put the input vector down each of the trees in the forest.
   Each tree gives a classification, and we say the tree "votes" for that class.
   The forest chooses the classification having the most votes (over all the trees in the forest).

   Each tree is grown as follows:
   - If the number of cases in the training set is N, sample N cases at random - but with replacement, from the original data.
     This sample will be the training set for growing the tree.
   - If there are M input variables, a number m<<M is specified such that at each node, m variables are selected at random out of the M
     and the best split on these m is used to split the node. The value of m is held constant during the forest growing.
   - Each tree is grown to the largest extent possible. There is no pruning. ..."

Configuration Input
   treeNum    number of trees to generate
   fsNum      number of features to sample each iteration
   Purity     p <= 1.0
   Depth      max tree level
*/
	EXPORT RandomForest(t_Count treeNum, t_Count fsNum, REAL Purity=1.0, INTEGER1 Depth=32):= MODULE
		EXPORT model_Map :=	DATASET([{'id','ID'},{'node_id','1'},{'level','2'},{'number','3'},{'value','4'},{'new_node_id','5'},{'group_id',6}], {STRING orig_name; STRING assigned_name;});
		EXPORT STRING model_fields := 'node_id,level,number,value,new_node_id,group_id';	// need to use field map to call FromField later
		EXPORT LearnD(DATASET(Types.DiscreteField) Indep, DATASET(Types.DiscreteField) Dep) := FUNCTION
			nodes := Trees.SplitFeatureSampleGI(Indep, Dep, treeNum, fsNum, Purity, Depth);
			AppendID(nodes, id, model);
			ToField(model, out_model, id, model_fields);
			RETURN out_model;
		END;
		EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
			ML.FromField(mod, Trees.gSplitF, o, model_Map);
			RETURN o;
		END;
		EXPORT ClassifyD(DATASET(Types.DiscreteField) Indep,DATASET(Types.NumericField) mod) := FUNCTION
			ML.FromField(mod, Trees.gSplitF, nodes, model_Map);	// need to use model_Map previously build when Learning (ToField)
			leafs := nodes(new_node_id = 0);	// from final nodes
			splitData_raw:= Trees.gSplitInstances(nodes, Indep);
			splitData:= DISTRIBUTE(splitData_raw, id);
			l_result final_class(RECORDOF(splitData) l, RECORDOF(leafs) r ):= TRANSFORM
				SELF.id     := l.id;
				SELF.number := 1;
				SELF.value  := r.value;
				SELF.conf   := 0;		// store percentaje of voting over total number of trees
				SELF.closest_conf:= 0;	// added to fit in l_result, not used so far
			END;
			gClass:= JOIN(splitData, leafs, LEFT.new_node_id = RIGHT.node_id AND LEFT.group_id = RIGHT.group_id, final_class(LEFT, RIGHT), LOOKUP);
			accClass:= TABLE(gClass, {id, number, value, cnt:= COUNT(GROUP)}, id, number, value, LOCAL);
			sClass := SORT(accClass, id, -cnt, LOCAL);
			finalClass:=DEDUP(sClass, id, LOCAL);
			RETURN PROJECT(finalClass, TRANSFORM(l_result, SELF.conf:= LEFT.cnt/treeNum, SELF:= LEFT, SELF:=[]), LOCAL);
		END;
	END; // RandomTree module
END;