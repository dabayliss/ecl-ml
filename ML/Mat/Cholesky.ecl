IMPORT * FROM $;
EXPORT Cholesky := MODULE
/*
This module performs Choleski matrix decomposition (http://en.wikipedia.org/wiki/Cholesky_decomposition).

Choleski triangle is a decomposition of a Hermitian, positive-definite matrix into the product of a 
lower triangular matrix and its conjugate transpose. When it is applicable, the Cholesky decomposition
is roughly twice as efficient as the LU decomposition.
*/


// Function returns the Cholesky triangle. 	
EXPORT DATASET(Types.Element) Decompose(DATASET(Types.Element) matrix) := FUNCTION
	n := Has(matrix).Dimension;
	loopBody(DATASET( Types.Element) ds, UNSIGNED4 k) := FUNCTION
				akk := ds(x=k AND y=k);
				lkk := Each.Sqrt(akk);
				col_k := Scale(ds(y=k, x>k), 1/lkk[1].value);
				l_lt := Mul(col_k,Trans(col_k));
				sub_m := Sub(ds(y>k AND x>=y),l_lt);
								
	RETURN Substitute(ds, sub_m+col_k+lkk);
  END;

	RETURN LowerTriangle(LOOP(matrix, n, loopBody(ROWS(LEFT),COUNTER)));
END;

END;