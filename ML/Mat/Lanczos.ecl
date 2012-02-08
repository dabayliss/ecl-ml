IMPORT * FROM $;
EXPORT Lanczos := MODULE

SHARED l_comp := ENUM ( A = 1,  V = 2, alpha = 3, beta = 4, T = 5 );
EXPORT DATASET(Types.Element) TV(DATASET(Types.Element) A) := FUNCTION

  // input matrix is square matrix
	N := Has(A).Dimension;
	// V(:,2)=V(:,2)/norm(V(:,2),2);
	B1 := 1000000;
	V00 := PROJECT( Vec.From(N),TRANSFORM(Types.Element,SELF.x := LEFT.x, SELF.Value := (RANDOM()%B1) / (REAL8)B1,SELF.y:=2));
	V0 := Scale(V00, 1/Vec.Norm(V00));
	Alpha0 := DATASET([],Types.Element);	
	Beta0 := DATASET([],Types.Element);	
	
	loopBody(DATASET( Types.MUElement) ds, UNSIGNED4 k) := FUNCTION
	  j := k+1;

		V := Mat.MU.From(ds, l_comp.V);
		Alpha := Mat.MU.From(ds, l_comp.alpha);
		Beta := Mat.MU.From(ds, l_comp.beta);
		//w = w - alpha(j)*V(:,j);
	  W := Sub(Mul(A, Vec.FromCol(V, j)), Vec.FromCol(Mul(Beta(y=j), V(y=j-1)),j-1));
		// alpha(j) = w'*V(:,j)
		newAlphaElem := Mul(Trans(W), V(y=j));
		Alpha1 := Alpha + newAlphaElem;
		W1 := Sub(W, Vec.FromCol(Mul(newAlphaElem,V(y=j)),j));
		// beta(j+1) = norm(W1)
		newBetaElem := PROJECT(Each.SQRT(Mul(Trans(W1), W1)),TRANSFORM(Types.Element,SELF.x:=1,SELF.y:=j+1,SELF := LEFT));
		Beta1 := Beta + newBetaElem;	
   	newVCol := PROJECT(W1,TRANSFORM(Types.Element,SELF.value:=LEFT.value/newBetaElem[1].value, SELF := LEFT));
		
	RETURN Mat.MU.To(V+Vec.ToCol(newVCol, j+1), l_comp.V)+Mat.MU.To(Alpha1, l_comp.alpha)+Mat.MU.To(Beta1, l_comp.beta);
  END;
	

	V_Alpha_Beta := LOOP(Mat.Mu.To(V0, l_comp.V)+	Mat.Mu.To(Alpha0, l_comp.alpha)+
		          				 Mat.Mu.To(Beta0, l_comp.beta), n+1, loopBody(ROWS(LEFT),COUNTER));
							
  // At this point, Alpha and Beta represent diagonal elements of the tri-diagonal 
	// symetric matrix T. 
	V := Mat.MU.From(V_Alpha_Beta, l_comp.V)(y<=n+2);
	Alpha := Mat.MU.From(V_Alpha_Beta, l_comp.alpha);
	Beta := Mat.MU.From(V_Alpha_Beta, l_comp.beta)(y<=n+2);
  T1 := Vec.ToDiag(Alpha, 2);
	T2 := Vec.ToUpperDiag(Beta,3);
	T3 := Vec.ToLowerDiag(Beta,3);
	RETURN Mat.Mu.To(V, l_comp.V) + Mat.Mu.To(T1+T2+T3, l_comp.T);
	
END;

EXPORT TComp(DATASET(Types.Element) matrix) := Mat.MU.From(TV(matrix), l_comp.T);
EXPORT VComp(DATASET(Types.Element) matrix) := Mat.MU.From(TV(matrix), l_comp.V)(y>1 AND y<Has(matrix).Dimension);


END;