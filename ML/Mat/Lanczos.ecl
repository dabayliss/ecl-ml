IMPORT * FROM $;

/*
	Lanczos method is a technique that can be used to solve eigenproblems (Ax = lambda*x)
	for a large, sparse, square, symmetric matrix. This method involves tridiagonalization of
	the given matrix, and unlike the Householder approach, no intermediate, full submatrices
	are generated. Equaly important, information about A's eigenvalues tends to emerge
	before tridiagonalization is complete. This makes the Lanczos algorithm useful in 
	situations where a few of A's largest or smallest eigenvalues are desired. 
	(Source: Golub and Van Loan, "Matrix Computations")

	Implementation based on: http://bickson.blogspot.com/search/label/Lanczos
*/
EXPORT Lanczos(DATASET(Types.Element) A, UNSIGNED eig_cnt) := MODULE

	SHARED l_comp := ENUM ( V = 1, alpha = 2, beta = 3, T = 4 );
	Stats := Has(A).Stats;
	
EXPORT DATASET(Types.Element) TV() := FUNCTION

	// V(:,2)=V(:,2)/norm(V(:,2),2);
	B1 := 1000000;
	V00 := PROJECT( Vec.From(Stats.YMax),TRANSFORM(Types.Element,SELF.x := LEFT.x, SELF.Value := (RANDOM()%B1) / (REAL8)B1,SELF.y:=2));	
	V0 := Scale(V00, 1/Vec.Norm(V00));
	Alpha0 := DATASET([],Types.Element);	
	Beta0 := DATASET([],Types.Element);	
	
	loopBody(DATASET( Types.MUElement) ds, UNSIGNED4 k) := FUNCTION
	  j := k+1;

		V := MU.From(ds, l_comp.V);
		Alpha := MU.From(ds, l_comp.alpha);
		Beta := MU.From(ds, l_comp.beta);
		// w = A*V(:,j) - beta(j)*V(:,j-1);
	  W := Sub(Mul(A, Vec.FromCol(V, j)), Scale(Vec.FromCol(V(y=j-1),j-1),Beta(y=j)[1].value));
		// alpha(j) = w'*V(:,j)
		newAlphaElem := Mul(Trans(W), V(y=j));
		Alpha1 := Alpha + newAlphaElem;
		//w1 = w - alpha(j)*V(:,j);
		W1 := Sub(W, Scale(Vec.FromCol(V(y=j),j),newAlphaElem[1].value));
		
		/*
		// ToDo: Orthogonalize
    for k=2:j-1
      tmpalpha = w'*V(:,k);
      w = w -tmpalpha*V(:,k);
    end
		*/
		
		// beta(j+1) = norm(W1)
		newBetaElem := PROJECT(Each.SQRT(Mul(Trans(W1), W1)),TRANSFORM(Types.Element,SELF.x:=1,SELF.y:=j+1,SELF := LEFT));
		Beta1 := Beta + newBetaElem;	
		// V(:,j+1) = w/beta(j+1);
   	newVCol := PROJECT(W1,TRANSFORM(Types.Element,SELF.value:=LEFT.value/newBetaElem[1].value, SELF := LEFT));
		
	RETURN MU.To(V+Vec.ToCol(newVCol, j+1), l_comp.V)+MU.To(Alpha1, l_comp.alpha)+MU.To(Beta1, l_comp.beta);
  END;
	

	V_Alpha_Beta := LOOP(Mu.To(V0, l_comp.V)+	Mu.To(Alpha0, l_comp.alpha)+
		          				 Mu.To(Beta0, l_comp.beta), eig_cnt, loopBody(ROWS(LEFT),COUNTER));
							
  // At this point, Alpha and Beta represent diagonal elements of the tri-diagonal 
	// symetric matrix T. 
	V := MU.From(V_Alpha_Beta, l_comp.V)(y<=eig_cnt+1);
	Vshift := PROJECT(V,TRANSFORM(Types.Element,SELF.y:=LEFT.y-1, SELF := LEFT));
	Alpha := Thin(MU.From(V_Alpha_Beta, l_comp.alpha));
	Beta := Thin(MU.From(V_Alpha_Beta, l_comp.beta)(y<=eig_cnt+1));
  T1 := Vec.ToDiag(Trans(Alpha), 2);
	T2 := Vec.ToUpperDiag(Trans(Beta),3);
	T3 := Vec.ToLowerDiag(Trans(Beta),3);
	RETURN Mu.To(Vshift, l_comp.V) + Mu.To(T1+T2+T3, l_comp.T);
	
END;

EXPORT TComp := MU.From(TV(), l_comp.T);
EXPORT VComp := MU.From(TV(), l_comp.V);

END;