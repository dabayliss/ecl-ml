IMPORT * FROM $;
EXPORT LU := MODULE

EXPORT L_component(DATASET(Types.Element) l_u) := PROJECT(l_u,TRANSFORM(Types.Element, SELF.Value := IF(LEFT.x=LEFT.y, 1, IF(LEFT.x>LEFT.y, LEFT.value, 0));SELF := LEFT));
EXPORT U_component(DATASET(Types.Element) l_u) := PROJECT(l_u,TRANSFORM(Types.Element, SELF.Value := IF(LEFT.x<=LEFT.y, LEFT.value, 0);SELF := LEFT));

EXPORT b_sub(DATASET(Types.Element) U, DATASET(Types.Element) b) := FUNCTION
  n := max(U, x);
	unn := U(x=n, y=n);
	b_wo_n := b(x<>n);
	b_w_n := b(x=n);
	scaled_b_n := Scale(b_w_n, 1/unn[1].value);
	new_b := b_wo_n + scaled_b_n;
	loopBody(DATASET( Types.Element) ds, unsigned4 k1) := FUNCTION	
				k := n-k1;
	      ukk := U(x=k, y=k);				
				yk_1 := Mul(U(x=k), ds(x>k));
				yk_2 := Sub(ds(x=k), yk_1(x=k));
				Types.Element replace(Types.Element le,Types.Element ri) := TRANSFORM
				BOOLEAN isMatched := ri.x>0;
						SELF.Value := IF(isMatched, ri.value/ukk[1].value, le.value);
						SELF := IF(isMatched, ri, le);
				END;
				yk := JOIN(ds,yk_2,LEFT.y=RIGHT.y AND LEFT.x = RIGHT.x,replace(LEFT,RIGHT),FULL OUTER);        
		RETURN yk;
  END;

	RETURN LOOP(new_b, max(U, x)-1, loopBody(ROWS(LEFT),counter));
END;

EXPORT f_sub(DATASET(Types.Element) L, DATASET(Types.Element) b) := FUNCTION

	loopBody(DATASET( Types.Element) ds, unsigned4 k1) := FUNCTION
								k := k1+1;
								//yk_1 := IF(k>1, Mul(L(x=k), ds(x<k)), ds);
								//yk_2 := IF(k>1,Sub(ds(x=k), yk_1(x=k)), yk_1);
								yk_1 := Mul(L(x=k), ds(x<k));
								yk_2 := Sub(ds(x=k), yk_1(x=k));
								Types.Element replace(Types.Element le,Types.Element ri) := TRANSFORM
										BOOLEAN isMatched := ri.x>0;
										SELF.Value := IF(isMatched, ri.value, le.value);
										SELF := IF(isMatched, ri, le);
								END;
								yk := JOIN(ds,yk_2,LEFT.y=RIGHT.y AND LEFT.x = RIGHT.x,replace(LEFT,RIGHT),FULL OUTER);
                
		RETURN yk;
  END;

	RETURN LOOP(b, max(L, x)-1, loopBody(ROWS(LEFT),counter));
END;

Types.Element replace_right(Types.Element le,Types.Element ri) := TRANSFORM
  BOOLEAN isMatched := ri.x>0;
  SELF.Value := IF(isMatched, ri.value, le.value);
  SELF := le;
  END;

loopBody(DATASET( Types.Element) ds, unsigned4 k) := FUNCTION
								akk := ds(x=k and y=k);
								lk := ds(y=k, x>k);
								lk1 := Scale(lk, 1/akk[1].value);
								leave1 := ds(y<=k or x<=k);							
								leave := JOIN(leave1, lk1, LEFT.x= RIGHT.x AND LEFT.y=RIGHT.y, replace_right(LEFT, RIGHT), LEFT OUTER);
								to_change := ds(x>k,y>k);

								a_k := JOIN(leave(y=k, x>k), leave(x=k, y>k), LEFT.y = RIGHT.x, 
								TRANSFORM(Types.Element, SELF.x := LEFT.x, SELF.y := RIGHT.y, SELF.value := LEFT.value*RIGHT.value));
								changed := Sub(to_change, a_k);;
								
	RETURN leave+changed;
  END;
	
EXPORT DATASET(Types.Element) Decompose(DATASET(Types.Element) matrix) := FUNCTION

	RETURN LOOP(matrix, max(matrix, x)-1, loopBody(ROWS(LEFT),counter));
END;


END;