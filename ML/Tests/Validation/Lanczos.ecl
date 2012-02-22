/*
	Lanczos Algorithm Validation Test:
		[T,V] = Lanczos(A); // T represents approximation of eigenvalues of A
    Approximation quality = norm(V*T*V'-A)

		[eigT_vec,eigT_val] = eig(T)
		eigA_vec = V*eigT_vec
		A*eigA_vec = eigA_vec*T
*/
IMPORT * FROM ML;
A := dataset([{1,1,12.0},{2,1,6.0},{3,1,4.0},
              {1,2,6.0},{2,2,167.0},{3,2,24.0},
	            {1,3,4.0},{2,3,24.0},{3,3,-41.0}], ML.MAT.Types.Element);

T:=ML.Mat.Lanczos(A,3).TComp;
V:=ML.Mat.Lanczos(A,3).VComp;
approxM := ML.Mat.Sub(ML.Mat.Mul(ML.Mat.Mul(V,T),ML.Mat.Trans(V)), A);
ApproximationQuality:= ML.Mat.Has(approxM).Norm;
OUTPUT(ApproximationQuality,named('Lanczos_Approximation_Quality'));

eigT_val:=ML.Mat.Eig(T).valuesM;
eigT_vec:=ML.Mat.Eig(T).vectors;
cnt:=(INTEGER)ML.Mat.Eig(T).convergence;
OUTPUT(eigT_val,named('Lanczos_Approximating_Eigenvalues'));
eigA_vec := ML.Mat.Mul(V,eigT_vec);
AlmostZero := ML.Mat.Sub(ML.Mat.Mul(A,eigA_vec),ML.Mat.Mul(eigA_vec,eigT_val));
OUTPUT(IF(EXISTS(ML.Mat.Thin(AlmostZero)),'Failed! Executed '+cnt+' eig iterations.','Passed! Eig values/vectors calculated in '+cnt+' steps!'),named('Lanczos_Test'));


