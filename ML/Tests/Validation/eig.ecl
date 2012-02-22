/*
	Eigenvalue Algorithm Validation Test:
		A*eig_vector = eig_vector*eig_values
*/
IMPORT * FROM ML;
A := dataset([{1,1,12.0},{2,1,6.0},{3,1,4.0},
              {1,2,6.0},{2,2,167.0},{3,2,24.0},
	            {1,3,4.0},{2,3,24.0},{3,3,-41.0}], ML.MAT.Types.Element);

eig_values:=ML.Mat.Eig(A).valuesM;
eig_vectors:=ML.Mat.Eig(A).vectors;
cnt:=(INTEGER)ML.Mat.Eig(A).convergence;
AlmostZero := ML.Mat.Sub(ML.Mat.Mul(A,eig_vectors),ML.Mat.Mul(eig_vectors,eig_values));
OUTPUT(IF(EXISTS(ML.Mat.Thin(AlmostZero)),'Failed','Passed! Eig values/vectors calculated in '+cnt+' steps!'),named('Eig_Test'));


