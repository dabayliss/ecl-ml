IMPORT * FROM $;
EXPORT InsertColumn(DATASET(Types.Element) d, Types.t_Index col_i, Types.t_value filler) := FUNCTION
seed := DATASET([{0,0,0}], Types.Element);
Types.Element add(Types.Element L, UNSIGNED4 c) := transform
    SELF.x := c;
		SELF.y := col_i;
		SELF.value := filler;
  END;

filler_col := NORMALIZE(seed, MAX(d,x) , add(LEFT, COUNTER));
Types.Element shiftRight(d le) := TRANSFORM
	  SELF.y := IF(le.y>= col_i, le.y +1, le.y);
	  SELF := le;
	END;
	d1 := PROJECT(d,shiftRight(LEFT));
	RETURN filler_col+d1;
  END;