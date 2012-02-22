IMPORT * FROM $;
IMPORT Config FROM ML;

/*
	http://en.wikipedia.org/wiki/Eigendecomposition_of_a_matrix
  A (non-zero) vector v of dimension N is an eigenvector of a square (N×N) matrix A if and only 
	if it satisfies the linear equation A*v = lambda*v where lambda is a scalar, termed the eigenvalue 
	corresponding to v. That is, the eigenvectors are the vectors which the linear transformation 
	A merely elongates or shrinks, and the amount that they elongate/shrink by is the eigenvalue. 
	The above equation is called the eigenvalue equation or the eigenvalue problem.

*/
EXPORT eig(DATASET(Types.Element) A, UNSIGNED4 iter=200) := MODULE
SHARED eig_comp := ENUM ( T = 1, Q = 2, conv = 3 );
EXPORT DATASET(Types.Element) QRalgorithm() := FUNCTION

		Q0 := Decomp.QComp(A);
		R0 := Decomp.RComp(A);
		T0 := Mul(R0, Q0);
		Conv0 := DATASET([{1,1,0}],Types.Element);
		
	loopBody(DATASET( Types.MUElement) ds, UNSIGNED4 k) := FUNCTION

		T := MU.From(ds, eig_comp.T);	
		Q := MU.From(ds, eig_comp.Q);
		Conv := MU.From(ds, eig_comp.conv);

		bConverged:= Vec.Norm(Vec.FromDiag(T,-1))<Config.RoundingError;
		
		QComp := Decomp.QComp(T);
		Q1 := Thin(Mul(Q,QComp));
		RComp := Decomp.RComp(T);
		T1 := Thin(Mul(RComp, QComp));
		Conv1 :=  PROJECT(Conv,TRANSFORM(Types.Element,SELF.value:=k, SELF := LEFT));

	RETURN IF(bConverged, ds, MU.To(T1, eig_comp.T)+MU.To(Q1, eig_comp.Q)+MU.To(Conv1, eig_comp.conv));
  END;
	
	RETURN LOOP(Mu.To(T0, eig_comp.T)+Mu.To(Q0, eig_comp.Q)+Mu.To(Conv0, eig_comp.conv), iter, loopBody(ROWS(LEFT),COUNTER));
END;

EXPORT valuesM := MU.From(QRalgorithm(), eig_comp.T);
EXPORT valuesV := Vec.FromDiag(valuesM());
EXPORT vectors := MU.From(QRalgorithm(), eig_comp.Q);
EXPORT convergence := MU.From(QRalgorithm(), eig_comp.conv)[1].value;

END;