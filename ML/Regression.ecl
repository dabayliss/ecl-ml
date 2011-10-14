IMPORT * FROM $;
IMPORT ML.mat as Mat;
/*
	The object of the regression module is to generate a regression model.
  A regression model relates the dependent variable Y to a function of
	the independent variables X, and a vector of unknown parameters Beta.
		Y = f(X,Beta)
	A regression model is an algorithm that estimates the unknown parameters 
  Beta so that a regression function Y = f(X,Beta) can be constructed
*/
EXPORT Regression := MODULE

// OrdinaryLeastSquares, aka LinearLeastSquares, the simplest and most common estimator 
// Beta = (Inv(X'*X)*X')*Y
EXPORT OLS(DATASET(Types.NumericField) X,DATASET(Types.NumericField) Y) := MODULE
  mX := Types.ToMatrix(X);
	mY := Types.ToMatrix(Y);
	mXt := Mat.Trans(mX);
  EXPORT Beta := Types.FromMatrix( Mat.Mul (Mat.Mul(Mat.Inv( Mat.Mul(mXt, mX) ), mXt), mY) );
END;
END;