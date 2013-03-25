//Extension of the OLS regression using dense matrices that performs an
//LU decomposition
IMPORT ML;
IMPORT ML.Types AS Types;
IMPORT PBblas as PBblas;
IMPORT ML.DMat as DMat;
IMPORT ML.Regression.Dense;
NotCompat := PBblas.Constants.Dimension_Incompat;
Matrix_Map:= PBblas.Matrix_Map;
LowerTri  := PBblas.Types.Triangle.Lower;
UpperTri  := PBblas.Types.Triangle.Upper;
NotUnit   := PBblas.Types.Diagonal.NotUnitTri;
Unit      := PBblas.Types.Diagonal.UnitTri;
Side      := PBblas.Types.Side;
Part      := PBblas.Types.Layout_Part;
NumericField := Types.NumericField;

EXPORT OLS_LU(DATASET(NumericField) X,DATASET(NumericField) Y)
:= MODULE(ML.Regression.Dense.OLS(X,Y))
  x2_map := Matrix_Map(x_rows, x_cols, block_rows, x_cols);
  y2_map := Matrix_Map(y_rows, y_cols, block_rows, y_cols);
  b2_map := Matrix_Map(x_cols, y_cols, x_cols, y_cols);
  z2_map := Matrix_Map(x_cols, x_cols, x_cols, x_cols);
  // Calculate the model beta matrix
  XtX_p := PBblas.PB_dbvrk(TRUE, 1.0, x2_map, x_part, z2_map);
  XtY_p := PBblas.PB_dbvmm(TRUE, FALSE, 1.0, x2_map, x_part, y2_map, y_part,
                          b2_map);
  LU_p  := PBblas.PB_dgetrf(z2_map, XtX_p);
  s1_p  := PBblas.PB_dtrsm(Side.Ax, LowerTri, FALSE, Unit, 1.0,
                          z2_map, LU_p, b2_map, XtY_p);
  b_part:= PBblas.PB_dtrsm(Side.Ax, UpperTri, FALSE, NotUnit, 1.0,
                          z2_map, LU_p, b2_map, s1_p);
  EXPORT DATASET(Part) BetasAsPartition := b_part;
END;