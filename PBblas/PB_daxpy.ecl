// Implements alpha C  + Y, X and Y must be compatible
IMPORT PBblas;
IMPORT PBblas.IMatrix_Map;
IMPORT PBblas.Types;
IMPORT PBblas.Constants;
IMPORT PBblas.BLAS;
IMPORT std.system.Thorlib;
Part := Types.Layout_Part;
value_t := Types.value_t;

EXPORT PB_daxpy(value_t alpha, DATASET(Part) X, DATASET(Part) Y) := FUNCTION
// Distribution must be right, maps must be compatible.
  x_check := ASSERT(X, node_id=Thorlib.node(), Constants.Distribution_Error, FAIL);
  y_check := ASSERT(Y, node_id=Thorlib.node(), Constants.Distribution_Error, FAIL);

  Part addPart(Part xrec, Part yrec) := TRANSFORM
    // ASSERT(xrec.begin_col = yrec.begin_col AND xrec.begin_row = xrec.end_row,
           // Constants.Dimension_Incompat, FAIL);
    cell_count := (yrec.end_row-yrec.begin_row+1) * (yrec.end_col-yrec.begin_col+1);
    SELF.mat_part := BLAS.daxpy(cell_count, alpha, xrec.mat_part, 1, yrec.mat_part, 1);
    SELF := yrec;
  END;
  rs := JOIN(x_check, y_check, LEFT.partition_id=RIGHT.partition_id,
             addPart(LEFT,RIGHT), FULL OUTER, LOCAL);
  RETURN rs;
END;