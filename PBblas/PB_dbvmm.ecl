// Multiply 2 Block Vectors   A row of blocks and a column of blocks.
//Special case of the matrix multiply to take advantage of product
//being a single block.
IMPORT PBblas;
IMPORT PBblas.Types;
IMPORT PBblas.BLAS;
IMatrix_Map := PBblas.IMatrix_Map;
Layout_Part := Types.Layout_Part;
Layout_Target := Types.Layout_Target;
value_t := Types.value_t;
dim_t := Types.dimension_t;
emptyC := DATASET([], Layout_Part);

EXPORT PB_dbvmm(BOOLEAN transposeA, BOOLEAN transposeB, value_t alpha,
                IMatrix_Map a_map, DATASET(Layout_Part) inA,
                IMatrix_Map b_map, DATASET(Layout_Part) inB,
                IMatrix_Map c_map, DATASET(Layout_Part) C=emptyC,
                value_t beta=0.0) := FUNCTION
// First check maps for compatability.  Normalize for transpose operations.
  a_matrix_rows := IF(transposeA, a_map.matrix_cols, a_map.matrix_rows);
  a_matrix_cols := IF(transposeA, a_map.matrix_rows, a_map.matrix_cols);
  a_row_blocks  := IF(transposeA, a_map.col_blocks,  a_map.row_blocks);
  a_col_blocks  := IF(transposeA, a_map.row_blocks,  a_map.col_blocks);
  b_matrix_rows := IF(transposeB, b_map.matrix_cols, b_map.matrix_rows);
  b_matrix_cols := IF(transposeB, b_map.matrix_rows, b_map.matrix_cols);
  b_row_blocks  := IF(transposeB, b_map.col_blocks,  b_map.row_blocks);
  b_col_blocks  := IF(transposeB, b_map.row_blocks,  b_map.col_blocks);
  c_matrix_rows := c_map.matrix_rows;
  c_matrix_cols := c_map.matrix_cols;
  c_row_blocks  := c_map.row_blocks;
  c_col_blocks  := c_map.col_blocks;
  A := ASSERT(inA,
              ASSERT(c_row_blocks=1 AND c_col_blocks=1,
                    'Product ' + PBblas.Constants.Not_Single_Block, FAIL),
              ASSERT(a_row_blocks=1, PBblas.Constants.Not_Block_Vector, FAIL),
              ASSERT(a_matrix_cols=b_matrix_rows AND a_col_blocks=b_row_blocks,
                    'A-B ' + PBblas.Constants.Dimension_Incompat, FAIL),
              ASSERT(a_matrix_rows=c_matrix_rows AND a_row_blocks=c_row_blocks,
                    'A-C ' + PBblas.Constants.Dimension_Incompat, FAIL));
  B := ASSERT(inB,
              ASSERT(c_row_blocks=1 AND c_col_blocks=1,
                    'Product ' + PBblas.Constants.Not_Single_Block, FAIL),
              ASSERT(b_col_blocks=1, PBblas.Constants.Not_Block_Vector, FAIL),
              ASSERT(a_matrix_cols=b_matrix_rows AND a_col_blocks=b_row_blocks,
                    'A-B ' + PBblas.Constants.Dimension_Incompat, FAIL),
              ASSERT(b_matrix_cols=c_matrix_cols AND b_col_blocks=c_col_blocks,
                    'B-C ' + PBblas.Constants.Dimension_Incompat, FAIL));
  // Join by partition number.  Both are compatible vectors of blocks,
  //so distribution is correct and partition assignments match.
  Layout_Part mul(Layout_Part a_part, Layout_Part b_part) := TRANSFORM
    k := IF(transposeA, a_part.part_rows, a_part.part_cols);
    m := IF(transposeA, a_part.part_cols, a_part.part_rows);
    n := IF(transposeB, b_part.part_rows, b_part.part_cols);
    SELF.mat_part := BLAS.dgemm(transposeA, transposeB, m, n, k,
                                alpha, a_part.mat_part, b_part.mat_part, 0.0);
    partition_id    := c_map.assigned_part(1, 1);
    SELF.node_id    := c_map.assigned_node(partition_id);
    SELF.partition_id := partition_id;
    SELF.block_row  := 1;
    SELF.block_col  := 1;
    SELF.first_row  := 1;
    SELF.first_col  := 1;
    SELF.part_rows  := m;
    SELF.part_cols  := n;
  END;
  a_dist := SORTED(DISTRIBUTED(A, node_id), partition_id);
  b_dist := SORTED(DISTRIBUTED(B, node_id), partition_id);
  dots   := JOIN(a_dist, b_dist, LEFT.partition_id=RIGHT.partition_id,
                 mul(LEFT, RIGHT), LOCAL);
  prod   := SORTED(DISTRIBUTE(dots, node_id), node_id, LOCAL);

  // Scale C by beta
  Layout_Part scaleC(Layout_Part part) := TRANSFORM
    N := part.part_rows * part.part_cols;
    SELF.mat_part := BLAS.dscal(N, beta, part.mat_part, 1);
    SELF := part;
  END;
  scaledC := SORTED(DISTRIBUTED(PROJECT(C, scaleC(LEFT)), node_id), partition_id);
  // Sum by part
  Layout_Part accumPart(Layout_Part accum, Layout_Part incr) := TRANSFORM
    N := accum.part_rows * accum.part_cols;
    SELF.mat_part := BLAS.daxpy(N, 1.0, incr.mat_part, 1, accum.mat_part, 1);
    SELF := accum;
  END;
  rslt := ROLLUP(prod + scaledC, accumPart(LEFT,RIGHT), node_id, LOCAL);
  RETURN rslt;
END;