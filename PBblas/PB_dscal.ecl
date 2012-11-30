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
    cells := lr.part_rows * lr.part_cols;
    SELF.mat_part := BLAS.dscal(cells, alpha, lr.mat_part, 1);
    SELF := lr;
  END;
  RETURN PROJECT(x, sm(LEFT));
END;