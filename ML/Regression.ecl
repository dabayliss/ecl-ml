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
  mX_0 := Types.ToMatrix(X);
	mX := Mat.InsertColumn(mX_0, 1, 1.0); // Insert X1=1 column 
	mXt := Mat.Trans(mX);
	mY := Types.ToMatrix(Y);
	Betas := Mat.Mul (Mat.Mul(Mat.Inv( Mat.Mul(mXt, mX) ), mXt), mY);
	// We want to return the data so that the ID field reflects the 'column number' of the variable we were targeting
	rBetas := Types.FromMatrix( Mat.Trans(Betas) );
	// We also need to move the 'constant' term into column 0
	sBetas := PROJECT(rBetas,TRANSFORM(Types.NumericField,SELF.Number := LEFT.Number-1,SELF := LEFT));
  EXPORT Beta := sBetas;
END;
END;