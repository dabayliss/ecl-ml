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
	SHARED mX := Mat.InsertColumn(mX_0, 1, 1.0); // Insert X1=1 column 
	SHARED mXt := Mat.Trans(mX);
	mY := Types.ToMatrix(Y);
	SHARED Betas := Mat.Mul (Mat.Mul(Mat.Inv( Mat.Mul(mXt, mX) ), mXt), mY);
	// We want to return the data so that the ID field reflects the 'column number' of the variable we were targeting
	rBetas := Types.FromMatrix( Mat.Trans(Betas) );
	// We also need to move the 'constant' term into column 0
	sBetas := PROJECT(rBetas,TRANSFORM(Types.NumericField,SELF.Number := LEFT.Number-1,SELF := LEFT));
  EXPORT Beta := sBetas;
	
	// use calculated estimator to predict Y values
	Y_estM := Mat.Trans(Mat.Mul(Mat.Trans(Betas) , mXt));	
	Y_est := Types.FromMatrix(Y_estM);
	// Y.number = number*2; Y_est.number = number*2+1;
	Y_est1 := PROJECT(Y_est, TRANSFORM(Types.NumericField, SELF.number := 2*LEFT.number+1; SELF := LEFT));
	Y1 := PROJECT(Y, TRANSFORM(Types.NumericField, SELF.number := 2*LEFT.number; SELF := LEFT));

	corr_ds := Correlate(Y1+Y_est1).Simple;

	CoRec := RECORD
		Types.t_fieldnumber number;
		Types.t_fieldreal   RSquared;
  END;

	CoRec getResult(corr_ds le) :=TRANSFORM 
		SELF.number := le.left_number/2; 
		SELF.RSquared := le.pearson*le.pearson ;
	END;
	// R^2 : square of the correlation coefficient between the observed and modeled (predicted) data values
	// Statistic that gives information about the goodness of fit of a model
	// It estimates the fraction of the variance in Y that is explained by X
  EXPORT RSquared := PROJECT(corr_ds(left_number&1=0,left_number+1=right_number), getResult(LEFT));	
END;
END;