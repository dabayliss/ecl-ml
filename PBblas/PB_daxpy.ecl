// Implements  alpha*X  + Y;  X and Y must be compatible
IMPORT PBblas;
IMPORT PBblas.IMatrix_Map;
IMPORT PBblas.Types;
IMPORT PBblas.Constants;
IMPORT PBblas.BLAS;
IMPORT std.system.Thorlib;
Part := Types.Layout_Part;
value_t := Types.value_t;
Dimension_IncompatZ := Constants.Dimension_IncompatZ;
Dimension_Incompat  := Constants.Dimension_Incompat;

EXPORT PB_daxpy(value_t alpha, DATASET(Part) X, DATASET(Part) Y) := FUNCTION
// Distribution must be right, maps must be compatible.
  x_check := ASSERT(X, node_id=Thorlib.node(), Constants.Distribution_Error, FAIL);
  y_check := ASSERT(Y, node_id=Thorlib.node(), Constants.Distribution_Error, FAIL);

  Part addPart(Part xrec, Part yrec) := TRANSFORM
    haveX := IF(xrec.part_cols=0, FALSE, TRUE);
    haveY := IF(yrec.part_cols=0, FALSE, TRUE);
    part_cols := IF(haveX, xrec.part_cols, yrec.part_cols);
    part_rows := IF(haveX, xrec.part_rows, yrec.part_rows);
    block_cols:= IF(NOT haveY OR part_cols=yrec.part_cols,
                    part_cols,
                    FAIL(UNSIGNED4, Dimension_IncompatZ, Dimension_Incompat));
    block_rows:= IF(NOT haveY OR part_rows=yrec.part_rows,
                    part_rows,
                    FAIL(UNSIGNED4, Dimension_IncompatZ, Dimension_Incompat));
    cell_count := block_rows * block_cols;
    axpy := BLAS.daxpy(cell_count, alpha, xrec.mat_part, 1, yrec.mat_part, 1);
    axonly := BLAS.dscal(cell_count, alpha, xrec.mat_part, 1);
    SELF.mat_part := MAP(haveX AND haveY    => axpy,
                         haveX              => axonly,
                         yrec.mat_part);
    SELF := IF(haveY, yrec, xrec);
  END;
  rs := JOIN(x_check, y_check, LEFT.partition_id=RIGHT.partition_id,
             addPart(LEFT,RIGHT), FULL OUTER, LOCAL);
  RETURN rs;
END;