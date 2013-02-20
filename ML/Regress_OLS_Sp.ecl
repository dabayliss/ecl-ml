IMPORT ML;
IMPORT ML.Types AS Types;
IMPORT Std.Str ;
IMPORT ML.mat as Mat;
NumericField := Types.NumericField;
/*
  The object of the regression module is to generate a regression model.
  A regression model relates the dependent variable Y to a function of
  the independent variables X, and a vector of unknown parameters Beta.
    Y = f(X,Beta)
  A regression model is an algorithm that estimates the unknown parameters
  Beta so that a regression function Y = f(X,Beta) can be constructed
*/

// OrdinaryLeastSquares, aka LinearLeastSquares, the simplest and most common estimator
// Beta = (Inv(X'*X)*X')*Y
EXPORT Regress_OLS_Sp(DATASET(NumericField) X,DATASET(NumericField) Y)
:= MODULE(ML.IRegression)
  mX_0 := Types.ToMatrix(X);
  SHARED mX := Mat.InsertColumn(mX_0, 1, 1.0); // Insert X1=1 column
  SHARED mXt := Mat.Trans(mX);
  SHARED mY := Types.ToMatrix(Y);
  // Calculate Betas for model
  mL := Mat.Decomp.Cholesky(Mat.Mul(mXt, mX));
  fsub := Mat.Decomp.f_sub(mL,Mat.Mul(mXt, mY));
  SHARED mBetas := Mat.Decomp.b_sub(Mat.Trans(mL), fsub);
  // We want to return the data so that the ID field reflects the 'column number' of
  //the variable we were targeting
  rBetas := Types.FromMatrix( Mat.Trans(mBetas) );
  // We also need to move the 'constant' term into column 0
  NumericField remapCol(NumericField lr) := TRANSFORM
    SELF.number := lr.number - 1;
    SELF := lr;
  END;
  sBetas := PROJECT(rBetas,remapCol(LEFT));
  EXPORT DATASET(NumericField) Betas := sBetas;

  // use calculated estimator to predict Y values
  Y_estM := Mat.Trans(Mat.Mul(Mat.Trans(mBetas) , mXt));
  EXPORT DATASET(NumericField) modelY := Types.FromMatrix(Y_estM);

  EXPORT DATASET(NumericField) Extrapolated(DATASET(NumericField) newX) := FUNCTION
    mX_0 := Types.ToMatrix(newX);
    mXloc := Mat.InsertColumn(mX_0, 1, 1.0); // Insert X1=1 column
    RETURN Types.FromMatrix( Mat.Mul(mXloc, Mat.Trans(mBetas)) );
  END;

  // Y.number = number*2; Y_est.number = number*2+1;
  Y_est1 := PROJECT(modelY, TRANSFORM(NumericField, SELF.number := 2*LEFT.number+1; SELF := LEFT));
  Y1 := PROJECT(Y, TRANSFORM(NumericField, SELF.number := 2*LEFT.number; SELF := LEFT));

  SHARED corr_ds := ML.Correlate(Y1+Y_est1).Simple;

  CoRec getResult(corr_ds le) :=TRANSFORM
    SELF.number := le.left_number/2;
    SELF.RSquared := le.pearson*le.pearson ;
  END;
  // R^2 : square of the correlation coefficient between the observed and modeled (predicted) data values
  // Statistic that gives information about the goodness of fit of a model
  // It estimates the fraction of the variance in Y that is explained by X
  rslt := PROJECT(corr_ds(left_number&1=0,left_number+1=right_number), getResult(LEFT));
  EXPORT DATASET(CoRec) RSquared := rslt;

  K := COUNT(ML.FieldAggregates(X).Cardinality); // # of independent (explanatory) variables
  Singles := ML.FieldAggregates(Y).Simple;
  tmpRec := RECORD
    RECORDOF(Singles);
    Types.t_fieldreal  RSquared;
  END;

  Singles1 := JOIN(Singles, RSquared, LEFT.number=RIGHT.number,
          TRANSFORM(tmpRec,  SELF.RSquared := RIGHT.RSquared, SELF := LEFT));

  AnovaRec := RECORD
    Types.t_fieldnumber   number;
    Types.t_RecordID      Model_DF; // Degrees of Freedom
    Types.t_fieldreal      Model_SS; // Sum of Squares
    Types.t_fieldreal      Model_MS; // Mean Square
    Types.t_fieldreal      Model_F;  // F-value
    Types.t_RecordID      Error_DF; // Degrees of Freedom
    Types.t_fieldreal      Error_SS;
    Types.t_fieldreal      Error_MS;
    Types.t_RecordID      Total_DF; // Degrees of Freedom
    Types.t_fieldreal      Total_SS;  // Sum of Squares
  END;

  AnovaRec getResult(tmpRec le) :=TRANSFORM
    SST := le.var*le.countval;
    SSM := SST*le.RSquared;

    SELF.number := le.number;
    SELF.Total_SS := SST;
    SELF.Model_SS := SSM;
    SELF.Error_SS := SST - SSM;
    SELF.Model_DF := k;
    SELF.Error_DF := le.countval-k-1;
    SELF.Total_DF := le.countval-1;
    SELF.Model_MS := SSM/k;
    SELF.Error_MS := (SST - SSM)/(le.countval-k-1);
    SELF.Model_F := (SSM/k)/((SST - SSM)/(le.countval-k-1));
  END;

  // http://www.stat.yale.edu/Courses/1997-98/101/anovareg.htm
  // Tested using the "Healthy Breakfast" dataset
  EXPORT Anova := PROJECT(Singles1, getResult(LEFT));
END;