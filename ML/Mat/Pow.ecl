IMPORT * FROM $;

// Raise the matrix d to the power of n (which must be positive)
EXPORT Pow(DATASET(Types.Element) d,UNSIGNED2 n) := FUNCTION

// Strategy: create a MU - with matrix 1 the target and matrix 2 the multiplier - perform the multiplication n-1 times
  m := MU.To(d,1)+MU.To(d,2);
	mult(DATASET(Types.MUElement) c) := FUNCTION
	  prod := Mul( MU.From(c,1), MU.From(C,2) );
		RETURN c(no=2)+MU.To(Prod,1);
	END;

	multi := LOOP( m, n-1, mult(ROWS(LEFT)) );

  RETURN IF ( n = 1, d, MU.From(multi,1) );
	
  END;