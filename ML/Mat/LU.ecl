IMPORT * FROM $;
EXPORT LU := MODULE
/*
This module performs LU matrix decomposition (http://en.wikipedia.org/wiki/LU_decomposition).

LU decomposition of a square matrix A writes a matrix A as the product of a lower triangular matrix L
and an upper triangular matrix U. This decomposition is used in numerical analysis to solve systems
of linear equations, calculate the determinant of a matrix, or calculate the inverse of an invertible
square matric.

This implementation is based on the Gaussian Elimination Algorithm
*/

// L and U components can reside in a single matrix because the lower triangular matrix L is assumed 
// all diagonal elements equal to 1 
EXPORT L_component(DATASET(Types.Element) l_u) := PROJECT(l_u,TRANSFORM(Types.Element, SELF.Value := IF(LEFT.x=LEFT.y, 1, IF(LEFT.x>LEFT.y, LEFT.value, 0));SELF := LEFT));
EXPORT U_component(DATASET(Types.Element) l_u) := PROJECT(l_u,TRANSFORM(Types.Element, SELF.Value := IF(LEFT.x<=LEFT.y, LEFT.value, 0);SELF := LEFT));

// Back substitution of LU Decomposition
EXPORT b_sub(DATASET(Types.Element) U, DATASET(Types.Element) b) := FUNCTION
	n := Has(U).Dimension;
	unn := U(x=n, y=n);
	b_wo_n := b(x<>n);
	b_w_n := b(x=n);
	scaled_b_n := Scale(b_w_n, 1/unn[1].value);
	new_b := b_wo_n + scaled_b_n;
	loopBody(DATASET( Types.Element) ds, UNSIGNED4 c) := FUNCTION	
				k := n-c;
	      ukk := U(x=k, y=k);				
				yk_1 := Mul(U(x=k), ds(x>k));
				yk_2 := Sub(ds(x=k), yk_1(x=k));
				/*
				Types.Element replace(Types.Element le,Types.Element ri) := TRANSFORM
						BOOLEAN isMatched := ri.x>0;
						SELF.Value := IF(isMatched, ri.value/ukk[1].value, le.value);
						SELF := IF(isMatched, ri, le);
				END;
				yk := JOIN(ds,yk_2,LEFT.y=RIGHT.y AND LEFT.x = RIGHT.x,replace(LEFT,RIGHT),FULL OUTER);        
        */
				yk_3 := Scale(yk_2, 1/ukk[1].value);
				yk := Substitute(ds, yk_3);
		RETURN yk;
  END;

	RETURN LOOP(new_b, n-1, loopBody(ROWS(LEFT),COUNTER));
END;

// Forward substitution of LU Decomposition
EXPORT f_sub(DATASET(Types.Element) L, DATASET(Types.Element) b) := FUNCTION
	n := Has(L).Dimension;
	loopBody(DATASET( Types.Element) ds, UNSIGNED4 c) := FUNCTION
				k := c+1;
				yk_1 := Mul(L(x=k), ds(x<k));
				yk_2 := Sub(ds(x=k), yk_1(x=k));
				/*
				Types.Element replace(Types.Element le,Types.Element ri) := TRANSFORM
						BOOLEAN isMatched := ri.x>0;
						SELF.Value := IF(isMatched, ri.value, le.value);
						SELF := IF(isMatched, ri, le);
				END;
				yk := JOIN(ds,yk_2,LEFT.y=RIGHT.y AND LEFT.x = RIGHT.x,replace(LEFT,RIGHT),FULL OUTER);        
        */
				yk := Substitute(ds,yk_2);
		RETURN yk;
  END;

	RETURN LOOP(b, n-1, loopBody(ROWS(LEFT),COUNTER));
END;
	
// LU Decomposition implemented using Gaussian Elimination Algorithm
// Function returns LU as a single matrix. 	
EXPORT DATASET(Types.Element) Decompose(DATASET(Types.Element) matrix) := FUNCTION
	n := Has(matrix).Dimension;
	loopBody(DATASET( Types.Element) ds, UNSIGNED4 k) := FUNCTION
				akk := ds(x=k AND y=k);
				lk := ds(y=k, x>k);
				lk1 := Scale(lk, 1/akk[1].value);
				leave1 := ds(y<=k OR x<=k);		
				/*
				Types.Element replace(Types.Element le,Types.Element ri) := TRANSFORM
						BOOLEAN isMatched := ri.x>0;
						SELF.Value := IF(isMatched, ri.value, le.value);
						SELF := le;
				END;
				leave := JOIN(leave1, lk1, LEFT.x= RIGHT.x AND LEFT.y=RIGHT.y, replace(LEFT, RIGHT), FULL OUTER);
        */
				leave := Substitute(leave1,lk1);
				to_change := ds(x>k,y>k);

				a_k := JOIN(leave(y=k, x>k), leave(x=k, y>k), LEFT.y = RIGHT.x, 
						TRANSFORM(Types.Element, SELF.x := LEFT.x, SELF.y := RIGHT.y, SELF.value := LEFT.value*RIGHT.value));
				changed := Sub(to_change, a_k);;
								
	RETURN leave+changed;
  END;

	RETURN LOOP(matrix, n-1, loopBody(ROWS(LEFT),COUNTER));
END;

END;