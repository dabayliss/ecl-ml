IMPORT * FROM $;

EXPORT Mul(DATASET(Types.Element) l,DATASET(Types.Element) r) := FUNCTION

	Types.Element Mu(l le,r ri) := TRANSFORM
		SELF.x := le.x;
		SELF.y := ri.y;
		SELF.value := le.value * ri.value;
	END;
	
  J := JOIN(l,r,LEFT.y=RIGHT.x,Mu(LEFT,RIGHT)); // Form all of the intermediate computations
	
	Inter := RECORD
		J.x;
		J.y;
		Types.t_value value := SUM(GROUP,J.value);
	END;
	
	T := TABLE(J,Inter,x,y,MERGE); // Combine all the parts back into a matrix - note if your matrices fit in memory on 1 node - FEW will help
	
	RETURN PROJECT( T , TRANSFORM( Types.Element, SELF := LEFT ) ); // Cast back into matrix type

END;

