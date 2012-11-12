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
    haveX := IF(xrec.begin_col=0, FALSE, TRUE);
    haveY := IF(yrec.begin_col=0, FALSE, TRUE);
    begin_col := IF(haveX, xrec.begin_col, yrec.begin_col);
    end_col   := IF(haveX, xrec.end_col, yrec.end_col);
    begin_row := IF(haveX, xrec.begin_row, yrec.begin_row);
    end_row   := IF(haveX, xrec.end_row, yrec.end_row);
    block_cols:= IF(NOT haveY OR (begin_col=yrec.begin_col AND end_col=yrec.end_col),
                    end_col - begin_col + 1,
                    FAIL(UNSIGNED4, Dimension_IncompatZ, Dimension_Incompat));
    block_rows:= IF(NOT haveY OR (begin_row=yrec.begin_row AND end_row=yrec.end_row),
                    end_row - begin_row + 1,
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