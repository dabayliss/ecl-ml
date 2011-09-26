IMPORT * FROM $;
EXPORT FieldAggregates(DATASET(Types.NumericField) d) := MODULE

SHARED iValueCount:=COUNT(TABLE(D,{id},id));
SHARED dDistributed:=SORT(DISTRIBUTE(d,number),number,-value,LOCAL);

SingleField := RECORD
  d.number;
	Types.t_fieldreal minval:=MIN(GROUP,d.Value);
	Types.t_fieldreal maxval:=MAX(GROUP,d.Value);
	Types.t_fieldreal sumval:=SUM(GROUP,d.Value);
	Types.t_fieldreal mean := AVE(GROUP,d.Value);
	Types.t_fieldreal var := VARIANCE(GROUP,d.Value);
END;
	
singles := table(dDistributed,SingleField,Number,LOCAL);	

s2 := RECORD
  singles;
	Types.t_fieldreal sd := SQRT(singles.var);
END;

EXPORT Simple := TABLE(singles,s2);

dWithPos:=TABLE(dDistributed,{dDistributed;UNSIGNED pos:=0;TYPES.t_FieldReal percentile:=0.0;});

RECORDOF(dWithPos) tRank(dWithPos L,dWithPos R):=TRANSFORM
  SELF.pos:=IF(L.number=R.number,L.pos+1,1);
	SELF.percentile:=((Types.t_FieldReal)SELF.pos-0.5)*(100/iValueCount); // Percentile by rank (can be used instead of the following join if desired)
	SELF:=R;
END;
dRanked:=ITERATE(dWithPos,tRank(LEFT,RIGHT),LOCAL);
// Uncomment one of the two lines below to get the preferred percentile value.
//EXPORT SimpleRanked:=ITERATE(dDistributed,tRank(LEFT,RIGHT),LOCAL);
EXPORT SimpleRanked:=JOIN(dRanked,Simple,LEFT.number=RIGHT.number,TRANSFORM(RECORDOF(dRanked),SELF.percentile:=100*((LEFT.value-RIGHT.minval)/(RIGHT.maxval-RIGHT.minval));SELF:=LEFT;),LOOKUP);

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