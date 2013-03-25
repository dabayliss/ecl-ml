IMPORT ML;
IMPORT ML.Types AS Types;
IMPORT ML.Utils AS Utils;
IMPORT Std.Str;
// OLS2Use := ML.Regression.Sparse.OLS_LU;
OLS2Use := ML.Regression.Dense.OLS_LU;

EXPORT Regress_Poly_X(DATASET(Types.NumericField) X,
                      DATASET(Types.NumericField) Y,
                      UNSIGNED1 maxN=6) := MODULE
  SHARED  newX := ML.Generate.ToPoly(X,maxN);

  SHARED B := OLS2Use(newX, Y);

  SHARED Pretty_Out := RECORD
    Types.t_RecordID id;
    STRING10 name;
    Types.t_FieldReal value;
  END;
  SHARED Pretty_Out  makePretty(Types.NumericField dt) := TRANSFORM
    SELF.name := ML.Generate.MethodName(dt.number);
    SELF := dt;
  END;
  EXPORT Beta := PROJECT(B.Betas, makePretty(LEFT));

  EXPORT RSquared := B.RSquared;

  // use K out of N polynomial components, and find the best model
  EXPORT SubBeta(UNSIGNED1 K, UNSIGNED1 N) := FUNCTION

    nk := Utils.NchooseK(N, K);
    R := RECORD
      REAL r2 := 0;
      nk.Kperm;
    END;
    // permutations
    perms := TABLE(nk, R);

    // evaluate permutations for the model fit based on RSquared
    R T(R le) := TRANSFORM
      x_subset := newX(number IN (SET OF INTEGER1)Str.SplitWords(le.Kperm, ' '));
      reg := OLS2Use(x_subset, Y);
      SELF.r2 := (reg.RSquared)[1].rsquared;
      SELF := le;
    END;

    fitDS := PROJECT(perms, T(LEFT));

    //winning permutation
    wperm := fitDS((r2=MAX(fitDS,r2)))[1].Kperm;
    x_winner := newX(number IN (SET OF INTEGER1)Str.SplitWords(wperm, ' '));
    wB := OLS2Use(x_winner, Y).Betas;

    prittyB := PROJECT(wB, ^.makePretty(LEFT));
    RETURN prittyB;
  END;
END;
