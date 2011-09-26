IMPORT * FROM $;
EXPORT FieldAggregates(DATASET(Types.NumericField) d) := MODULE

SingleField := RECORD
  d.number;
	Types.t_fieldreal mean := AVE(GROUP,d.Value);
	Types.t_fieldreal var := VARIANCE(GROUP,d.Value);
	END;
	
singles := table(d,SingleField,Number);	

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

RankableField find_starts(P le,P ri) := TRANSFORM
  SELF.Pos := IF ( le.Number=ri.Number, 0, ri.pos );
  SELF := ri;
  END;

Splits := ITERATE(SORT(DISTRIBUTE(P,Number),Number,LOCAL),find_starts(LEFT,RIGHT),LOCAL)(Pos > 0);

RankableField to_1(P le,Splits ri) := TRANSFORM
	SELF.Pos := 1+le.Pos - ri.Pos;
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