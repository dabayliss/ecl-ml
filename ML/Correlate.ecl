IMPORT * FROM $;
EXPORT Correlate(DATASET(Types.NumericField) d) := MODULE
  Singles := FieldAggregates(d).Simple;

PairRec := RECORD
  Types.t_FieldNumber left_number;
	Types.t_FieldNumber right_number;
	Types.t_fieldreal   xy;
	END;

PairRec note_prod(d le, d ri) := TRANSFORM
  SELF.left_number := le.number;
	SELF.right_number := ri.number;
	SELF.xy := le.value*ri.value;
  END;
	
pairs := JOIN(d,d,LEFT.id=RIGHT.id AND LEFT.number<RIGHT.number,note_prod(LEFT,RIGHT));

PairAccum := RECORD
  pairs.left_number;
	pairs.right_number;
	e_xy := AVE(GROUP,pairs.xy);
  END;
	
exys := TABLE(pairs,PairAccum,left_number,right_number,FEW); // Few will die for VERY large numbers of variables ...	

with_x := JOIN(exys,singles,LEFT.left_number = RIGHT.number,LOOKUP);

CoRec := RECORD
  Types.t_fieldnumber left_number;
	Types.t_fieldnumber right_number;
	Types.t_fieldreal   covariance;
	Types.t_fieldreal   pearson;
  END;

CoRec MakeCo(with_x le, singles ri) := TRANSFORM
  SELF.covariance := (le.e_xy - le.mean*ri.mean);
  SELF.pearson := (le.e_xy - le.mean*ri.mean)/(le.sd*ri.sd);
  SELF := le;
  END;

  EXPORT Simple := JOIN(with_x,singles,LEFT.right_number=RIGHT.number,MakeCo(LEFT,RIGHT),LOOKUP);

OrderedPairRec := RECORD
	Types.t_RecordID  left_rid;
	Types.t_RecordID  right_rid;
	Types.t_FieldNumber number;
  Types.t_FieldReal left_value;
	Types.t_FieldReal right_value;
	Types.t_FieldSign sign;
	END;

OrderedPairRec calculate_rank_direction(d le, d ri) := TRANSFORM
  SELF.left_rid := le.id;
	SELF.right_rid := ri.id;
  SELF.number := le.number;
  SELF.left_value := le.value;
	SELF.right_value := ri.value;
	SELF.sign := IF(le.value<ri.value, 1, IF(le.value=ri.value, 0, -1));
  END;
	
sequenced_pairs := JOIN(d,d,LEFT.number=RIGHT.number AND LEFT.id<RIGHT.id,calculate_rank_direction(LEFT,RIGHT));

PairRec := RECORD
  Types.t_FieldNumber left_number;
	Types.t_FieldNumber right_number;
	Types.t_FieldSign   sign;
	END;

PairRec calculate_cordance(OrderedPairRec le, OrderedPairRec ri) := TRANSFORM
  SELF.left_number := le.number;
	SELF.right_number := ri.number;
	SELF.sign := le.sign*ri.sign;
  END;

pairs := JOIN(sequenced_pairs,sequenced_pairs, LEFT.right_rid=RIGHT.right_rid AND LEFT.left_rid=RIGHT.left_rid AND LEFT.number<RIGHT.number,calculate_cordance(LEFT,RIGHT));
//pairs;

PairAccum := RECORD
  pairs.left_number;
	pairs.right_number;
	kendall_tau := AVE(GROUP,pairs.sign);
  END;
	
EXPORT Kendall := TABLE(pairs,PairAccum,left_number,right_number,FEW);	

/*
	Mutual Information is a statistic that measures how much a value informs another value.
	cVec is the number of the column that is informed by the remaining columns in the record set
	units is the unit of measurement for MutualInfo to calculate
	buckets is the amount of buckets for the Discretize.ByBucketing method to distribute values into
*/
EXPORT MutualInfo(UNSIGNED cVec,UNSIGNED units=2,UNSIGNED buckets = 10)	:= FUNCTION
	dis := Discretize.ByBucketing(d,buckets);

	LOGN(REAL x) := FUNCTION
		RETURN LOG(x)/LOG(units);
	END;

	ProbRec := RECORD
		UNSIGNED number;
		UNSIGNED value;
		UNSIGNED class;
		REAL probability;
	END;

	ProbPRec := RECORD
		ProbRec;
		REAL mprobability;
	END;

	DiscreteFieldP := RECORD
		Types.DiscreteField;
		UNSIGNED class;
	END;

	DiscreteFieldP AddClass(Types.DiscreteField L, Types.DiscreteField R)	:= TRANSFORM
		SELF.class := R.value;
		SELF := L;
	END;

	pDis1	:= dis(number<>cVec);
	pDis2	:= dis(number=cVec);
	jDis	:= JOIN(pDis1,pDis2,LEFT.id = RIGHT.id,AddClass(LEFT,RIGHT));

	CCountRec	:= RECORD
		class	:= pDis2.value;
		total	:= COUNT(GROUP);
	END;

	tCCount	:= TABLE(pDis2,CCountRec,value,MERGE);
	cCCount	:= SUM(tCCount,total);

	CondProbPRec := RECORD
		UNSIGNED class;
		REAL	mprobability;
	END;

	CondProbPRec CalcMProb(CCountRec L, UNSIGNED total_all)	:= TRANSFORM
		SELF.class := L.class;
		SELF.mprobability := L.total/total_all;
	END;

	ProbPRec AddMProb(ProbRec L, CondProbPRec R)	:= TRANSFORM
		SELF.mprobability	:= R.mprobability;
		SELF	:= L;
	END;

	dMProb := PROJECT(tCCount,CalcMProb(LEFT,cCCount));

	GroupRec := RECORD
		jDis.number;
		jDis.value;
		jDis.class;
		total	:= COUNT(GROUP);
	END;
	
	tDis := TABLE(jDis,GroupRec,number,value,class,MERGE);

	ProbRec JointProb(GroupRec L, UNSIGNED total_all)	:= TRANSFORM
		SELF.number	:= L.number;
		SELF.value	:= L.value;
		SELF.class	:= L.class;
		SELF.probability := L.Total/total_all;
	END;

	dJoint := PROJECT(tDis,JointProb(LEFT,cCCount));
	dJointP := JOIN(dJoint,dMProb,LEFT.class = RIGHT.class,AddMProb(LEFT,RIGHT));

	NVCountRec := RECORD
		jdis.number;
		jdis.value;
		total	:= COUNT(GROUP);
	END;

	tNVCount := TABLE(jDis,NVCountRec,number,value,MERGE);

	NVProbRec	:= RECORD
		UNSIGNED number;
		UNSIGNED value;
		REAL probability;
	END;

	NVProbRec ToNVProb(NVCountRec L, UNSIGNED total_all)	:= TRANSFORM
		SELF.probability := L.total/total_all;
		SELF := L;
	END;

	dNVCount := PROJECT(tNVCount,ToNVProb(LEFT,cCCount));

	ProbRec CondProb (ProbPRec L, NVProbRec R)	:= TRANSFORM
		SELF.probability := L.probability/R.probability;
		SELF := L;
	END;

	dCond	:= JOIN(dJointP,dNVCount,LEFT.number = RIGHT.number AND LEFT.value = RIGHT.value,CondProb(LEFT,RIGHT));

	EntropyRec := RECORD
		UNSIGNED number;
		REAL marginal;
		REAL conditional;
	END;

	EntropyRec CalcEntropy(ProbPRec L,ProbRec R)	:= TRANSFORM
		SELF.number := L.number;
		SELF.marginal := L.mprobability * LOGN(L.mprobability);
		SELF.conditional := L.probability * LOGN(R.probability);
	END;

	EntropyRec SumEntropy(EntropyRec L, EntropyRec R)	:= TRANSFORM
		SELF.number	:= L.number;
		SELF.marginal	:= L.marginal + R.marginal;
		SELF.conditional := L.conditional + R.conditional;
	END;

	MutualInfoRec	:= RECORD
		UNSIGNED number;
		REAL mi;
	END;

	MutualInfoRec	CalcMi(EntropyRec L)	:= TRANSFORM
		SELF.number	:= L.number;
		SELF.mi := (-1*L.marginal) - (-1*L.conditional);
	END;

	dEntropy := JOIN(dJointP,dCond,LEFT.value = RIGHT.value AND LEFT.class = RIGHT.class AND LEFT.number = RIGHT.number,CalcEntropy(LEFT,RIGHT));

	EntropyRRec	:= RECORD
		dEntropy.number;
		marginal := SUM(GROUP,dEntropy.marginal);
		conditional := SUM(GROUP,dEntropy.conditional);
	END;

	dEntropyRollup := TABLE(dEntropy,EntropyRRec,number,MERGE);
	dMi	:= PROJECT(dEntropyRollup,CalcMi(LEFT));
	RETURN dMi;
END;

END;