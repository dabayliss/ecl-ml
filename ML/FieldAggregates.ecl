IMPORT * FROM $;
EXPORT FieldAggregates(DATASET(Types.NumericField) d) := MODULE

SingleField := RECORD
  d.number;
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
	UNSIGNED Pos;
  END;

RankableField add_rank(D le,UNSIGNED c) := TRANSFORM
  SELF.Pos := c;
	SELF := le;
  END;
	
P := PROJECT(SORT(D,Number,-Value),add_rank(LEFT,COUNTER));

RS := RECORD
  LowPos := MIN(GROUP,P.Pos);
  P.Number;
  END;

Splits := TABLE(P,RS,Number,FEW);

RankableField to_1(P le,Splits ri) := TRANSFORM
	SELF.Pos := 1+le.Pos - ri.LowPos;
	SELF := le;
  END;
	
EXPORT SimpleRanked := JOIN(P,Splits,LEFT.Number=RIGHT.Number,to_1(LEFT,RIGHT),LOOKUP);

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