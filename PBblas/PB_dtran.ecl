// Transpose a matrix and sum into base matrix
// result <== alpha A**t  + beta C, A is n by m, C is m by n
IMPORT PBblas;
IMPORT PBblas.Types;
IMPORT PBblas.IMatrix_Map;
Layout_Part := Types.Layout_Part;
Layout_Target := Types.Layout_Target;
value_t := Types.value_t;
matrix_t:= Types.matrix_t;
dimension_t := Types.dimension_t;
emptyC := DATASET([], Layout_Part);
matrix_t empty_matrix := [];

// use C/C++ to manipulate the dense array
matrix_t dtran(dimension_t m, dimension_t n,
               value_t alpha, matrix_t A,
               value_t beta,  matrix_t C) := BEGINC++
  #body
  __isAllResult = false;
  __lenResult = m * n * sizeof(double);
  double *result = new double[m * n];
  // populate if provided, set to zero if not
  for(int i=0; i<m*n; i++) {
    result[i] = (__lenResult==lenC && beta!=0.0)
              ? beta * (((double*)c)[i])
              : 0.0;
  }
  // Column major store used
  int r2c, c2r, target_pos, source_pos;
  for (c2r=0; c2r<m; c2r++) {   // A has m columns
    for (r2c=0; r2c<n; r2c++) {
      source_pos = (c2r*n) + r2c;
      target_pos = (r2c*m) + c2r;
      result[target_pos] += alpha*((double*)a)[source_pos];
    }
  }
  __result = (void *) result;
ENDC++;

EXPORT PB_dtran(IMatrix_Map map_a, IMatrix_Map map_c,
                value_t alpha, DATASET(Layout_Part) A,
                value_t beta=0.0, DATASET(Layout_Part) C=emptyC) := FUNCTION
// Need to check compatibility between map_a and map_c
  a_checked := ASSERT(A, map_a.matrix_rows = map_c.matrix_cols AND
                         map_a.matrix_cols = map_c.matrix_rows AND
                         map_a.row_blocks  = map_c.col_blocks  AND
                         map_a.col_blocks  = map_c.row_blocks,
                      PBblas.Constants.Dimension_Incompat, FAIL);
  Layout_Target reLabel(Layout_Part lr) := TRANSFORM
    target_part       := map_c.assigned_part(lr.block_col, lr.block_row);
    SELF.t_term       := 0;   // not used for simple routing
    SELF.t_block_row  := lr.block_col;
    SELF.t_block_col  := lr.block_row;
    SELF.t_part_id    := target_part;
    SELF.t_node_id    := map_c.assigned_node(target_part);
    SELF := lr;
  END;
  a_marked := PROJECT(a_checked, reLabel(LEFT));
  a_dist   := SORT(DISTRIBUTE(a_marked, t_node_id), t_part_id, LOCAL);
  c_sorted := SORT(C, partition_id, LOCAL);
  // JOIN the partititions together
  Layout_Part transpose(Layout_Target a_part, Layout_Part c_part) := TRANSFORM
    c_mat := IF(c_part.partition_id<>0, c_part.mat_part, empty_matrix);
    a_mat := IF(a_part.partition_id<>0, a_part.mat_part, empty_matrix);
    block_row := IF(c_part.partition_id<>0, c_part.block_row, a_part.t_block_row);
    block_col := IF(c_part.partition_id<>0, c_part.block_col, a_part.t_block_col);
    part_id := IF(c_part.partition_id<>0, c_part.partition_id, a_part.t_part_id);
    part_rows := map_c.part_rows(part_id);
    part_cols := map_c.part_cols(part_id);
    SELF.mat_part := dtran(part_rows, part_cols, alpha, a_mat, beta, c_mat);
    SELF.partition_id := part_id;
    SELF.node_id := map_c.assigned_node(part_id);
    SELF.block_row := block_row;
    SELF.block_col := block_col;
    SELF.first_row := map_c.first_row(part_id);
    SELF.part_rows := part_rows;
    SELF.first_col := map_c.first_col(part_id);
    SELF.part_cols := part_cols;
  END;
  rslt := JOIN(a_dist, C, LEFT.t_part_id=RIGHT.partition_id,
               transpose(LEFT, RIGHT), FULL OUTER, LOCAL, LIMIT(1), NOSORT);
  RETURN rslt;
END;