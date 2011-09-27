IMPORT * FROM $;
EXPORT Sub(DATASET(Types.Element) l,DATASET(Types.Element) r) := FUNCTION
// Only slight nastiness is that these matrices may be sparse - so either side could be null
Types.Element Su(l le,r ri) := TRANSFORM
    SELF.x := IF ( le.x = 0, ri.x, le.x );
    SELF.y := IF ( le.y = 0, ri.y, le.y );
	  SELF.value := le.value - ri.value; // Fortuitously; 0 is the null value
  END;
	RETURN JOIN(l,r,LEFT.x=RIGHT.x AND LEFT.y=RIGHT.y,Su(LEFT,RIGHT),FULL OUTER);
  END;