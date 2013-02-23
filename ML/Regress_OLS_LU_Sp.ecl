// Use LU factorization
IMPORT ML;
IMPORT ML.Types AS Types;
IMPORT Std.Str ;
IMPORT ML.mat as Mat;
NumericField := Types.NumericField;

EXPORT Regress_OLS_LU_Sp(DATASET(NumericField) X,DATASET(NumericField) Y)
:= MODULE(ML.Regress_OLS_Sp(X,Y))
  // Use LU factorization
  mLU := Mat.Decomp.LU(Mat.Mul(mXt, mX));
  mL  := Mat.Decomp.LComp(mLU);
  mU  := Mat.Decomp.UComp(mLU);
  fsub := Mat.Decomp.f_sub(mL,Mat.Mul(mXt, mY));
  rslt := Mat.Decomp.b_sub(mU, fsub);
  SHARED DATASET(Mat.Types.Element) mBetas := rslt;
END;