IMPORT * FROM $;
EXPORT FieldAggregates(DATASET(Types.NumericField) d) := MODULE

SingleField := RECORD
  d.number;
	Types.t_fieldreal minval:=MIN(GROUP,d.Value);
	Types.t_fieldreal maxval:=MAX(GROUP,d.Value);
	Types.t_fieldreal sumval:=SUM(GROUP,d.Value);
  Types.t_fieldreal countval:=COUNT(GROUP);
	Types.t_fieldreal mean := AVE(GROUP,d.Value);
	Types.t_fieldreal var := VARIANCE(GROUP,d.Value);
	END;
	
singles := TABLE(d,SingleField,Number,FEW);	

s2 := RECORD
  singles;
	Types.t_fieldreal sd := SQRT(singles.var);
  END;

EXPORT Simple := TABLE(singles,s2);

RankableField := RECORD
  d;
	UNSIGNED Pos := 0;
  END;

T := TABLE(SORT(D,Number,Value),RankableField);

Utils.mac_SequenceInField(T,Number,Pos,P)

dWithPercentile:=JOIN(P,Simple,LEFT.number=RIGHT.number,TRANSFORM({RECORDOF(p);Types.t_FieldReal percentile;},SELF.percentile:=100*((LEFT.value-RIGHT.minval)/(RIGHT.maxval-RIGHT.minval));SELF:=LEFT;),LOOKUP);

EXPORT SimpleRanked := dWithPercentile;

EXPORT fBucketize(UNSIGNED iBuckets):=FUNCTION
  RETURN TABLE(SimpleRanked,{SimpleRanked;UNSIGNED bucket:=IF(percentile=0.0,1,percentile/(100/iBuckets));});
END;

MR := RECORD
  SimpleRanked.Number;
	SimpleRanked.Value;
	Types.t_FieldReal Pos := AVE(GROUP,SimpleRanked.Pos);
	END;

T := TABLE(SimpleRanked,MR,Number,Value);	

AveRanked := 	RECORD
  d;
	Types.t_FieldReal Pos;
  END;
	
AveRanked Into(D le,T ri) := 	TRANSFORM
  SELF.Pos := ri.pos;
  SELF := le;
  END;
	
EXPORT Ranked := JOIN(D,T,LEFT.Number=RIGHT.Number AND LEFT.Value = RIGHT.Value,Into(LEFT,RIGHT));	

  END;