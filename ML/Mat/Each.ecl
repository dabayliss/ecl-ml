// Element-wise matrix operations
IMPORT * FROM $;
EXPORT Each := MODULE

EXPORT Sqrt(DATASET(Types.Element) d) := FUNCTION
  Types.Element fn(d le) := TRANSFORM
	  SELF.value := sqrt(le.value);
	  SELF := le;
	END;
	RETURN PROJECT(d,fn(LEFT));
  END;
	
END;