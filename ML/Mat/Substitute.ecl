IMPORT * FROM ML.Mat;
EXPORT Substitute(DATASET(Types.Element) l,DATASET(Types.Element) r) := FUNCTION
// Substitutes the elements of the l matrix with the corresponding non-zero elements from 
// the r matrix. For example:
// Substitute([L11, L12, L22], [R11, R21]) = [R11, L12, R21, L22]
Types.Element Su(l le,r ri) := TRANSFORM
		BOOLEAN isMatched := ri.x>0 ;
    SELF.x := IF ( isMatched, ri.x, le.x );
    SELF.y := IF ( isMatched, ri.y, le.y );
	  SELF.value := IF ( isMatched, ri.value, le.value ); 
  END;
	RETURN JOIN(l,r(Value<>0),LEFT.x=RIGHT.x AND LEFT.y=RIGHT.y,Su(LEFT,RIGHT),FULL OUTER);
  END;
