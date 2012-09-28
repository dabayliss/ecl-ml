// Implements result <- alpha*op(A)op(B) + beta*C.  op is No Transpose or Transpose.
//Result has same matrix map as C.
IMPORT PBblas.Types;
IMPORT PBblas.IMatrix_Map;
IMPORT BLAS;

emptyC := DATASET([], Types.Layout_Part;


EXPORT PB_dgemm(BOOLEAN transposeA, BOOLEAN transposeB, Types.value_t alpha,
                IMatrix_Map map_a, DATASET(Types.Layout_Part) A,
                IMatrix_Map map_b, DATASET(Types.Layout_Part) B,
                IMatrix_Map map_c, DATASET(Types.Layout_Part) C=emptyC,
                Types.value_t beta=0.0) := FUNCTION
// First check maps for compatability, must be all the same layout
//and dimensions must be consistent, partitions and partition contents
// Perform transpositions as required to achieve layout compatability.
//
  Matrix_Name := ENUM{UNSIGNED1, C=1, A=2, B=3};

  Work_Base := RECORD
    Types.node_t      node_id;
    Types.partition_t partition_id;
    Types.dimension_t block_row;
    Types.dimension_t block_col;
  END;
  Work_Mat := RECORD
    Types.dimension_t part_rows;
    Types.dimension_t part_cols;
    matrix_t          mat_part;
    Matrix_Name       mat_name;
  END;
  Work_In := RECORD
    Work_Base;
    Work_Mat;
  END;
  Work_In cvt(Types.Layout_Part par, INTEGER c, BOOLEAN byCol,
            Matrix_Name mat, IMatrix_Map mat_map)) := TRANSFORM
    part_id_row       := mat_map.assigned_part(c, par.block_col);
    part_id_col       := mat_map.assigned_part(par.block_row, c);
    partition_id      := IF(byCol, part_id_col, part_id_row);
    SELF.node_id      := mat_map.node_assigned(partition_id);
    SELF.partition_id := partition_id;
    SELF.block_row    := par.block_row;
    SELF.block_col    := par.block_col;
    SELF.part_rows    := par.end_row - par.begin_row + 1;
    SELF.part_cols    := par.end_col - par.end_col + 1;
    SELF.mat_part     := par.mat_part;
  END;

  // A: copy of each cell in a row goes to a column
  a_work := NORMALIZE(A, map_a.col_blocks,
                      cvt(LEFT, COUNTER, TRUE, Matrix_Name.A, map_a));
  a_dist := DISTRIBUTE(a_work, node_id);
  a_sort := SORT(a_dist, partition_id, LOCAL);
  // B: copy of each cell in a column goes to a row
  b_work := NORMALIZE(B, map_b.row_blocks,
                      cvt(LEFT, COUNTER, FALSE, Matrix_Name.B, map_b));
  b_dist := DISTRIBUTE(b_work, node_id);
  b_sort := SORT(b_dist, partition_id, LOCAL);


END;