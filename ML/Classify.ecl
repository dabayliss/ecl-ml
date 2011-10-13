IMPORT * FROM $;
/*
		The object of the classify module is to generate a classifier.
    A classifier is an 'equation' or 'algorithm' that allows the 'class' of an object to be imputed based upon other properties
    of an object.
*/

EXPORT Classify := MODULE

SHARED SampleCorrection := 1;
SHARED LogScale(REAL P) := -LOG(P)/LOG(2);

/* Naive Bayes Classification 
	 This method can support producing classification results for multiple classifiers at once
	 Note the presumption that the result (a weight for each value of each field) can fit in memory at once
*/

SHARED BayesResult := RECORD
	  Types.t_discrete c;
		Types.t_discrete f := 0;
		Types.t_FieldNumber number := 0; // Number of the field in question - 0 for the case of a P(C)
		Types.t_FieldNumber class_number;
		REAL8 P; // Either P(F|C) or P(C) if number = 0. Stored in -Log2(P) - so small is good :)
		Types.t_Count Support; // Number of cases
  END;

/*
  The inputs to the BuildNaiveBayes are:
  a) A dataset of discretized independant variables
  b) A dataset of class results (these must match in ID the discretized independant variables).
     Some routines can produce multiple classifiers at once; if so these are distinguished using the NUMBER field of cl
*/
EXPORT BuildNaiveBayes(DATASET(Types.DiscreteField) dd,DATASET(Types.DiscreteField) cl) := FUNCTION
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
  CLTots := TABLE(CTots,{number,TSupport := SUM(GROUP,Support)},number,FEW);
	
	P_C_Rec := RECORD
	  Types.t_Discrete c; // The value within the class
		Types.t_Discrete class_number; // Used when multiple classifiers being produced at once
		Types.t_FieldReal support;  // Used to store total number of C
		REAL8 P; // P(C)
	END;
	P_C_Rec pct(CTots le,CLTots ri) := TRANSFORM
		SELF.c := le.value;
		SELF.class_number := ri.number;
		SELF.support := le.Support;
		SELF.P := le.Support/ri.TSupport;
	END;
	PC := JOIN(CTots,CLTots,LEFT.number=RIGHT.number,pct(LEFT,RIGHT),FEW);
	
	// We do NOT want to assume every value exists for every field - so we will count the number of class values by field
	TotalFs := TABLE(Cnts,{c,number,class_number,Types.t_Count Support := SUM(GROUP,Support),GC := COUNT(GROUP)},c,number,class_number,FEW);
	F_Given_C_Rec := RECORD
	  Cnts.c;
		Cnts.f;
		Cnts.number;
		Cnts.class_number;
		Cnts.support;
		REAL8 P;	
	END;
	F_Given_C_Rec mp(Cnts le,TotalFs ri) := TRANSFORM
	  SELF.P := (le.Support+SampleCorrection) / (ri.Support+ri.GC*SampleCorrection);
		SELF := le;
	END;
	FC := JOIN(Cnts,TotalFs,LEFT.C = RIGHT.C AND LEFT.number=RIGHT.number AND LEFT.class_number=RIGHT.class_number,mp(LEFT,RIGHT),LOOKUP);

	Pret := PROJECT(FC,TRANSFORM(BayesResult,SELF := LEFT))+PROJECT(PC,TRANSFORM(BayesResult,SELF:=LEFT));
	RETURN PROJECT(Pret,TRANSFORM(BayesResult,SELF.P := LogScale(LEFT.P),SELF := LEFT));
END;

// This function will take a pre-existing NaiveBayes model (mo) and score every row of a discretized dataset
// The output will have a row for every row of dd and a column for every class in the original training set
EXPORT NaiveBayes(DATASET(Types.DiscreteField) d,DATASET(BayesResult) mo) := FUNCTION
  // Firstly we can just compute the support for each class from the bayes result
	dd := DISTRIBUTE(d,HASH(id)); // One of those rather nice embarassingly parallel activities
	Inter := RECORD
	  Types.t_discrete c;
		Types.t_discrete class_number;
		Types.t_RecordId Id;
		REAL8  P;
	END;
	Inter note(dd le,mo ri) := TRANSFORM
	  SELF.c := ri.c;
		SELF.class_number := ri.class_number;
		SELF.id := le.id;
		SELF.P := ri.p;
	END;
	// RHS is small so ,ALL join should work ok
	// Ignore the "explicitly distributed" compiler warning - the many lookup is preserving the distribution
	J := JOIN(dd,mo,LEFT.number=RIGHT.number AND LEFT.value=RIGHT.f,note(LEFT,RIGHT),MANY LOOKUP);
	InterCounted := RECORD
	  J.c;
		J.class_number;
		J.id;
		REAL8 P := SUM(GROUP,J.P);
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
	  SELF.P := le.P+ri.P+le.Missing*LogScale(SampleCorrection/ri.support);
	  SELF := le;
	END;
	CNoted := JOIN(MissingNoted,mo(number=0),LEFT.c=RIGHT.c,NoteC(LEFT,RIGHT),LOOKUP);
	S := DEDUP(SORT(CNoted,Id,class_number,P,c,LOCAL),Id,class_number,LOCAL,KEEP(2));
	BayesClassification := RECORD
	  S.c;
		S.class_number;
		S.id;
		REAL8 P := S.P;
		REAL8 ClosestP := 0;
	END;
	ST := TABLE(S,BayesClassification);
  BayesClassification rem(ST le, ST ri) := TRANSFORM
	  SELF.ClosestP := ri.P;
	  SELF := le;
  END;
	Ro := ROLLUP(ST,LEFT.id=RIGHT.id AND LEFT.class_number=RIGHT.class_number,rem(LEFT,RIGHT),LOCAL);
	RETURN Ro;
  END;
	
EXPORT TestNaiveBayes(DATASET(Types.DiscreteField) d,DATASET(Types.DiscreteField) cl,DATASET(BayesResult) mo) := MODULE
  N := NaiveBayes(d,mo);
	DiffRec := RECORD
		Types.t_FieldNumber classifier; // The classifier in question (value of 'number' on outcome data)
		Types.t_Discrete c_actual;      // The value of c provided
		Types.t_Discrete c_modeled;			// The value produced by the classifier
		Types.t_Discrete score;         // Score allocated by classifier
		Types.t_Discrete score_delta;   // Difference to next best
		BOOLEAN          sole_result;   // Did the classifier only have one option
	END;
	DiffRec  notediff(N le,cl ri) := TRANSFORM
	  SELF.c_actual := ri.value;
		SELF.c_modeled := le.c;
		SELF.score := 1+ROUND(le.p);
		SELF.score_delta := IF ( le.closestp>0, 1+ROUND(le.closestp-le.p),0 );
		SELF.sole_result := le.closestp=0;
		SELF.classifier := ri.number;
	END;
	SHARED J := JOIN(N,cl,LEFT.id=RIGHT.id AND LEFT.class_number=RIGHT.number,notediff(LEFT,RIGHT));
	// Shows which classes were modeled as which classes
	EXPORT Raw := TABLE(J,{classifier,c_actual,c_modeled,score,score_delta,sole_result,Cnt := COUNT(GROUP)},classifier,c_actual,c_modeled,score,score_delta,sole_result,MERGE);
	EXPORT CrossAssignments := TABLE(J,{classifier,c_actual,c_modeled,Cnt := COUNT(GROUP)},classifier,c_actual,c_modeled,FEW);
	EXPORT PrecisionByClass := TABLE(J,{classifier,c_actual, Precision := AVE(GROUP,IF(c_actual=c_modeled,100,0))},classifier,c_actual,FEW);
	EXPORT HeadLine := TABLE(J,{classifier, Precision := AVE(GROUP,IF(c_actual=c_modeled,100,0))},classifier,FEW);
END;

/*
  The inputs to the BuildPerceptron are:
  a) A dataset of discretized independant variables
  b) A dataset of class results (these must match in ID the discretized independant variables).
  Note the perceptron presently assumes the class values are ordinal eg 4>3>2>1>0
  The classic 'boolean' case should be handled with -1 and 1
*/
EXPORT BuildPerceptron(DATASET(Types.DiscreteField) dd,DATASET(Types.DiscreteField) cl) := FUNCTION
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
		Types.t_FieldNumber number; // The field this weight applies to - note field 0 will be the bias
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
		  SELF.number := C;
		  SELF.class_number := le.number;
		END;
		RETURN NORMALIZE(Classes,MaxFieldNumber+1,again(LEFT,COUNTER-1));
	END;

  AccumRec := RECORD
		DATASET(WR) Weights;
		DATASET(VR) ThisRecord;
		string rem := '';
	END;
	// The learn step for a perceptrom
	Learn(DATASET(WR) le,DATASET(VR) ri,Types.t_FieldNumber fn,Types.t_Discrete va) := FUNCTION
	  WR add(WR le,VR ri) := TRANSFORM
		  SELF.w := le.w+1;
			SELF := le;
		END;
		RETURN JOIN(le,ri,LEFT.number=right.number,add(LEFT,RIGHT),LEFT OUTER);
		//RETURN PROJECT(le,TRANSFORM(WR,SELF.w := LEFT.w+1,SELF := LEFT));
	END;
	// This takes a record one by one and processes it
	// That may mean simply appending it to 'ThisRecord' - or it might mean performing a learning step
	AccumRec TakeRecord(ready le,AccumRec ri) := TRANSFORM
	  BOOLEAN lrn := le.number >= FirstClassNo;
		BOOLEAN init := ~EXISTS(ri.Weights);
		SELF.Weights := MAP ( init => InitWeights, 
		                      //~lrn => ri.Weights,
													//PROJECT(ri.Weights,TRANSFORM(WR,SELF.w := 1, SELF := LEFT)) );
													Learn(ri.Weights,ri.ThisRecord,le.number,le.value) );
		// This is either an independant variable - in which case we append it
		// Or it is the last dependant variable - in which case we can throw the record away
		// Or it is one of the dependant variables - so keep the record for now
		SELF.ThisRecord := MAP ( ~lrn => ri.ThisRecord+ROW({le.number,le.value},VR),
		                         le.number = LastClassNo => DATASET([],VR),
														 ri.ThisRecord);
		self.rem := ri.rem+'{'+IF(init,'init:','')+le.number+','+MAX(SELF.Weights,w)+'}';
	END;
	A := AGGREGATE(ready,AccumRec,TakeRecord(LEFT,RIGHT),LOCAL);
	RETURN A;
END;
END;