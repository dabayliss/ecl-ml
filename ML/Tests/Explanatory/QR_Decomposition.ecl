IMPORT * FROM ML;
A := dataset([{1,1,12.0},{2,1,6.0},{3,1,-4.0},{4,1,-1.0},
              {1,2,-51.0},{2,2,167.0},{3,2,24.0},{4,2,4.0},
	            {1,3,4.0},{2,3,-68.0},{3,3,-41.0},{4,3,-1.0}], ML.MAT.Types.Element);

Q := ML.Mat.Decomp.QComp(A);
R := ML.Mat.Decomp.RComp(A);
QR := ML.Mat.Mul(Q,R);
// A-QR is a zero matrix
ML.Mat.Thin(ML.MAT.RoundDelta(ML.Mat.Sub(A,QR)));
// Q is an orthonormal matrix: Q*Q' = I
ML.Mat.Thin(ML.MAT.RoundDelta(ML.Mat.Mul(Q,ML.Mat.Trans(Q))));