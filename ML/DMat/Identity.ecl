//Dense matrix identity
IMPORT PBblas;
Part := PBblas.Types.Layout_Part;
IMatrix_Map := PBblas.IMatrix_Map;
t_matrix := PBblas.Types.matrix_t;
t_dimension := PBblas.Types.dimension_t;
// populate block
t_matrix popBlock(t_dimension m) := BEGINC++
  #body
  __lenResult = m * m * sizeof(double);
  __isAllResult = false;
  double *rslt = new double[m*m];
  __result = (void*) rslt;
  for (int i=0; i<m*m; i++) rslt[i] = 0.0;
  for (int i=0; i<m*m; i+=m+1) rslt[i] = 1.0;
ENDC++;
EXPORT DATASET(Part) Identity(IMatrix_Map i_map) := FUNCTION
  seed := DATASET([{i_map.row_blocks}], {UNSIGNED dim});
  Part generate(seed lr, UNSIGNED c) := TRANSFORM
    part_id           := i_map.assigned_part(c,c);
    SELF.partition_id := part_id;;
    SELF.node_id      := i_map.assigned_node(part_id);
    SELF.block_row    := c;
    SELF.block_col    := c;
    SELF.first_row    := i_map.first_row(part_id);
    SELF.part_rows    := i_map.part_rows(part_id);
    SELF.first_col    := i_map.first_col(part_id);
    SELF.part_cols    := i_map.part_cols(part_id);
    SELF.mat_part     := popBlock(i_map.part_rows(part_id));
  END;
  d0 := NORMALIZE(seed, LEFT.dim, generate(LEFT,COUNTER));
  rslt := SORT(DISTRIBUTE(d0, node_id), partition_id, LOCAL);
  RETURN rslt;
END;