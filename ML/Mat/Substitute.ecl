IMPORT * FROM $;
EXPORT Substitute(DATASET(Types.Element) l,DATASET(Types.Element) r) := FUNCTION
// Only slight nastiness is that these matrices may be sparse - so either side could be null
Types.Element Su(l le,r ri) := TRANSFORM
		BOOLEAN isMatched := ri.x>0 ;
    SELF.x := IF ( isMatched, ri.x, le.x );
    SELF.y := IF ( isMatched, ri.y, le.y );
	  SELF.value := IF ( isMatched, ri.value, le.value ); // Fortuitously; 0 is the null value
  END;
	RETURN JOIN(l,r,LEFT.x=RIGHT.x AND LEFT.y=RIGHT.y,Su(LEFT,RIGHT),FULL OUTER);
  END;
