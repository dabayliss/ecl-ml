//Matrix update with a block vector.
//Form is alpha A A**t  + beta C or alpha A**t A  + beta C
//where C is NxN and A is NxK (KxN with transpose set to TRUE)
//C must be a single partition.
//
IMPORT PBblas;
IMPORT PBblas.Types;
IMPORT PBblas.BLAS;
Layout_Part := Types.Layout_Part;
value_t := Types.value_t;
emptyC := DATASET([], Layout_Part);

EXPORT PB_dbvrk(BOOLEAN transposeA, value_t alpha, PBblas.IMatrix_Map a_map,
                DATASET(Layout_Part) A, PBblas.IMatrix_Map c_map,
                value_t beta=0.0, DATASET(Layout_Part) C=emptyC) := FUNCTION
  // Verify maps are OK
  tran_ok := a_map.col_blocks=c_map.row_blocks
         AND a_map.col_blocks=c_map.col_blocks
         AND a_map.matrix_cols=c_map.matrix_rows
         AND a_map.matrix_cols=c_map.matrix_cols
         AND c_map.col_blocks=1 AND c_map.row_blocks=1;
  dim_ok  := a_map.row_blocks=c_map.row_blocks
         AND a_map.row_blocks=c_map.col_blocks
         AND a_map.matrix_rows=c_map.matrix_rows
         AND a_map.matrix_rows=c_map.matrix_cols
         AND c_map.row_blocks=1 AND c_map.col_blocks=1;
  compat  := IF(transposeA, tran_ok, dim_ok);
  a_ok := ASSERT(A, ASSERT(compat, PBblas.Constants.Dimension_Incompat, FAIL));
  c_ok := SORTED(DISTRIBUTED(C, node_id), partition_id, LOCAL);
  // product by block
  Layout_Part mult(Layout_Part part) := TRANSFORM
    part_id := c_map.assigned_part(1, 1);
    k := IF(transposeA, part.part_rows, part.part_cols);
    m := c_map.part_rows(part_id);
    n := c_map.part_cols(part_id);
    SELF.mat_part := BLAS.dgemm(transposeA, ~transposeA,
                                m, n, k,
                                alpha, part.mat_part, part.mat_part, 0.0);
    SELF.partition_id := part_id;
    SELF.node_id := c_map.assigned_node(part_id);
    SELF.block_row := 1;
    SELF.block_col := 1;
    SELF.first_row := 1;
    SELF.part_rows := m;
    SELF.first_col := 1;
    SELF.part_cols := n;
  END;
  sq := DISTRIBUTE(PROJECT(a_ok, mult(LEFT)), node_id);
  // Scale C by beta
  Layout_Part scaleC(Layout_Part part) := TRANSFORM
    N := c_map.matrix_rows * c_map.matrix_cols;
    SELF.mat_part := BLAS.dscal(N, beta, part.mat_part, 1);
    SELF := part;
  END;
  scaledC := DISTRIBUTE(PROJECT(c_ok, scaleC(LEFT)), node_id);
  // Sum by part
  Layout_Part accumPart(Layout_Part accum, Layout_Part incr) := TRANSFORM
    N := c_map.matrix_rows * c_map.matrix_cols;
    SELF.mat_part := BLAS.daxpy(N, 1.0, incr.mat_part, 1, accum.mat_part, 1);
    SELF := accum;
  END;
  rslt := ROLLUP(sq + scaledC, accumPart(LEFT,RIGHT), node_id, LOCAL);
  RETURN rslt;
END;