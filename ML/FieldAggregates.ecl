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

EXPORT SimpleRanked := P;

{RECORDOF(SimpleRanked);Types.t_NTile ntile;} tNTile(SimpleRanked L,Simple R,Types.t_NTile n):=TRANSFORM
  SELF.ntile:=IF(L.pos=R.countval,n,(Types.t_NTile)(n*(L.pos/R.countval))+1);
  SELF:=L;
END;
EXPORT NTiles(Types.t_NTile n):=JOIN(SimpleRanked,Simple,LEFT.number=RIGHT.number,tNTile(LEFT,RIGHT,n),LOOKUP);
EXPORT NTileRanges(Types.t_NTile n):=TABLE(NTiles(n),{number;ntile;Types.t_fieldreal Min:=MIN(GROUP,value);Types.t_fieldreal Max:=MAX(GROUP,value);UNSIGNED cnt:=COUNT(GROUP);},number,ntile);

{RECORDOF(SimpleRanked);Types.t_Bucket bucket;} tAssign(SimpleRanked L,Simple R,Types.t_Bucket n):=TRANSFORM
  SELF.bucket:=IF(L.value=R.maxval,n,(Types.t_Bucket)(n*((L.value-R.minval)/(R.maxval-R.minval)))+1);
  SELF:=L;
END;
EXPORT Buckets(Types.t_Bucket n):=JOIN(SimpleRanked,Simple,LEFT.number=RIGHT.number,tAssign(LEFT,RIGHT,n),LOOKUP);
EXPORT BucketRangess(Types.t_Bucket n):=TABLE(Buckets(n),{number;bucket;Types.t_fieldreal Min:=MIN(GROUP,value);Types.t_fieldreal Max:=MAX(GROUP,value);UNSIGNED cnt:=COUNT(GROUP);},number,bucket);

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