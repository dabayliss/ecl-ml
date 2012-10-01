// Implements result <- alpha*op(A)op(B) + beta*C.  op is No Transpose or Transpose.
//Result has same matrix map as C.
IMPORT PBblas.Types;
IMPORT PBblas.IMatrix_Map;
IMPORT PBBlas.BLAS;
Layout_Part := Types.Layout_Part;
Layout_Target := Types.Layout_Target;
value_t := Types.value_t;
emptyC := DATASET([], Layout_Part);
SET OF value_t empty_array := [];

EXPORT PB_dgemm(BOOLEAN transposeA, BOOLEAN transposeB, value_t alpha,
                IMatrix_Map map_a, DATASET(Layout_Part) A,
                IMatrix_Map map_b, DATASET(Layout_Part) B,
                IMatrix_Map map_c, DATASET(Layout_Part) C=emptyC,
                value_t beta=0.0) := FUNCTION
// First check maps for compatability, must be all the same layout
//and dimensions must be consistent, partitions and partition contents
// Perform transpositions as required to achieve layout compatability.
//
  Layout_Target cvt(Layout_Part par, INTEGER c, BOOLEAN byCol) := TRANSFORM
    part_id_row       := map_c.assigned_part(c, par.block_col);
    part_id_col       := map_c.assigned_part(par.block_row, c);
    partition_id      := IF(byCol, part_id_col, part_id_row);
    SELF.t_node_id    := map_c.assigned_node(partition_id);
    SELF.t_part_id    := partition_id;
    SELF.t_block_row  := IF(byCol, par.block_row, c);
    SELF.t_block_col  := IF(byCol, c, par.block_col);
    SELF              := par;
  END;

  // A: copy of each cell in a row goes to a column
  a_work := NORMALIZE(A, map_a.col_blocks, cvt(LEFT, COUNTER, TRUE));
  a_dist := DISTRIBUTE(a_work, t_node_id);
  a_sort := SORT(a_dist, t_part_id, LOCAL);
  // B: copy of each cell in a column goes to a row
  b_work := NORMALIZE(B, map_b.row_blocks, cvt(LEFT, COUNTER, FALSE));
  b_dist := DISTRIBUTE(b_work, t_node_id);
  b_sort := SORT(b_dist, t_part_id, LOCAL);
  // Multiply
  Layout_Part mul(Layout_Target a_part, Layout_Target b_part):=TRANSFORM
    part_id     := a_part.t_part_id;    //arbitrary choice
    part_a_cols := a_part.end_col - a_part.begin_col + 1;
    part_a_rows := a_part.end_row - a_part.begin_row + 1;
    part_b_rows := b_part.end_row - b_part.begin_row + 1;
    part_c_rows := map_c.part_rows(part_id);
    k := IF(transposeA, part_a_cols, part_a_rows);
    SELF.partition_id := part_id;
    SELF.node_id      := a_part.t_node_id;
    SELF.block_row    := a_part.t_block_row;
    SELF.block_col    := a_part.t_block_col;
    SELF.begin_row    := map_c.first_row(part_id);
    SELF.end_row      := map_c.part_rows(part_id)+map_c.first_row(part_id)-1;
    SELF.begin_col    := map_c.first_col(part_id);
    SELF.end_col      := map_c.part_cols(part_id)+map_c.first_col(part_id)-1;
    SELF.array_layout := map_c.array_layout;
    SELF.mat_part     := BLAS.dgemm(map_c.array_layout, transposeA, transposeB,
                                    map_c.matrix_rows, map_c.matrix_cols, k,
                                    alpha, a_part.mat_part, part_a_rows,
                                    b_part.mat_part, part_b_rows,
                                    0.0, empty_array, part_c_rows);
  END;
  ab_prod := JOIN(a_sort, b_sort,
                  LEFT.t_part_id=RIGHT.t_part_id AND LEFT.block_row=RIGHT.block_col
                  AND LEFT.block_col=RIGHT.block_row,
                  mul(LEFT,RIGHT), LOCAL);

  // Apply beta
  Layout_Part applyBeta(Layout_Part part) := TRANSFORM
    SELF.mat_part := BLAS.dscal(map_c.matrix_rows*map_c.matrix_cols,
                                beta, part.mat_part, 1);
    SELF          := part;
  END;
  upd_C := PROJECT(C, applyBeta(LEFT));

  // Sum terms
  Layout_Part sumTerms(Layout_Part cumm, Layout_Part term) := TRANSFORM
    N := map_c.part_rows(cumm.partition_id) * map_c.part_cols(cumm.partition_id);
    SELF.mat_part := BLAS.daxpy(N, 1.0, cumm.mat_part, 1, term.mat_part, 1);
    SELF := cumm;
  END;
  sorted_terms := SORT(upd_c+ab_prod, partition_id, LOCAL);
  rslt := ROLLUP(sorted_terms, sumTerms(LEFT, RIGHT), partition_id, LOCAL);
  RETURN rslt;
END;