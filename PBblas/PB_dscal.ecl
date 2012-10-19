IMPORT PBblas;
IMPORT PBblas.IMatrix_Map;
IMPORT PBblas.Types;
IMPORT PBblas.Constants;
IMPORT PBblas.BLAS;
IMPORT std.system.Thorlib;
Part := Types.Layout_Part;
value_t := Types.value_t;

EXPORT PB_dscal(value_t alpha, DATASET(Part) X) := FUNCTION
  Part sm(Part lr) := TRANSFORM
    cells := (lr.end_row-lr.begin_row+1) * (lr.end_col-lr.begin_col+1);
    SELF.mat_part := BLAS.dscal(cells, alpha, lr.mat_part, 1);
    SELF := lr;
  END;
  RETURN PROJECT(x, sm(LEFT));
END;