// Define the Regression interface for various regression implementation.
//
IMPORT ML.Types;
IMPORT PBblas.Types AS DMatTypes;
IMPORT ML.Mat.Types AS MatTypes;
NumericField := Types.NumericField;
/*
  The object of the regression module is to generate a regression model.
  A regression model relates the dependent variable Y to a function of
  the independent variables X, and a vector of unknown parameters Beta.
    Y = f(X,Beta)
  A regression model is an algorithm that estimates the unknown parameters
  Beta so that a regression function Y = f(X,Beta) can be constructed
*/

EXPORT IRegression := MODULE,VIRTUAL
  EXPORT CoRec := RECORD
    Types.t_fieldnumber number;
    Types.t_fieldreal   RSquared;
  END;
  // The model parameter estimates
  EXPORT DATASET(NumericField) betas;
  // The predicted values of Y
  EXPORT DATASET(NumericField) modelY;
  // Extrapolated (interpolated) values of Y based upon provided X values
  EXPORT DATASET(NumericField) Extrapolated(DATASET(NumericField) newX);
  // The R Squared values for the parameters
  EXPORT DATASET(CoRec)  RSquared;
END;