//Take a dataset of cells for a partition and pack into a dense matrix.  Specify Row or Column major
//First row and first column are one based.
//Insert is used insert columns with a spacific value.  Typical use is building a matrix for a solver
//where the first column is an inserted column of 1 values for the intercept.
IMPORT PBblas;
IMPORT PBblas.Types;
Layout_Part := Types.Layout_Part;
Layout_Cell := Types.Layout_Cell;
//IMPORT PBblas.Matrix_Map;
IMPORT ML.Types AS ML_Types;

EXPORT DMAT(PBblas.IMatrix_Map mat_map) := MODULE
  SHARED Work1 := RECORD(Types.Layout_Cell)
    Types.partition_t     partition_id;
    Types.node_t          node_id;
  END;
  EXPORT FromCells(DATASET(Layout_Cell) cells,
                   Types.dimension_t insert_columns=0,
                   Types.value_t insert_value=0.0d) := FUNCTION
    Work1 cvt_2_xcell(Layout_Cell lr) := TRANSFORM
      row_block           := mat_map.row_block(lr.x);
      col_block           := mat_map.col_block(lr.y + insert_columns);
      partition_id        := mat_map.assigned_part(row_block, col_block);
      SELF.partition_id   := partition_id;
      SELF.node_id        := mat_map.assigned_node(partition_id);
      SELF := lr;
    END;
    d0 := PROJECT(cells, cvt_2_xcell(LEFT));
    d1 := DISTRIBUTE(d0, node_id);
    d2 := SORT(d1, partition_id, y, x, LOCAL);    // prep for column major
    d3 := GROUP(d2, partition_id, LOCAL);
    Layout_Part roll_cells(Work1 parent, DATASET(Work1) cells) := TRANSFORM
      first_row     := mat_map.first_row(parent.partition_id);
      first_col     := mat_map.first_col(parent.partition_id);
      part_rows     := mat_map.part_rows(parent.partition_id);
      part_cols     := mat_map.part_cols(parent.partition_id);
      SELF.mat_part := PBblas.MakeR8Set(part_rows, part_cols, first_row, first_col,
                                        PROJECT(cells, Layout_Cell),
                                        mat_map.array_layout,
                                        insert_columns, insert_value);
      SELF.partition_id:= parent.partition_id;
      SELF.node_id     := parent.node_id;
      SELF.begin_row   := first_row;
      SELF.begin_col   := first_col;
      SELF.end_row     := first_row + part_rows - 1;
      SELF.end_col     := first_col + part_cols - 1;
      SELF.array_layout:= mat_map.array_layout;
      SELF := [];
    END;
    rslt := ROLLUP(d3, GROUP, roll_cells(LEFT, ROWS(LEFT)));
    RETURN rslt;
  END;
  // Convert from dense to sparse
  Layout_Cell cvtPart2Cell(Layout_Part pr, UNSIGNED4 c) := TRANSFORM
    SELF.v  := pr.mat_part[c];
    SELF.x  := mat_map.first_row(pr.partition_id) + mat_map.block_row(c) - 1;
    SELF.y  := mat_map.first_col(pr.partition_id) + mat_map.block_col(c) - 1;
  END;
  EXPORT FromPart2Cell(DATASET(Layout_Part) part_recs) :=
    NORMALIZE(part_recs, COUNT(LEFT.mat_part), cvtPart2Cell(LEFT, COUNTER));

  // From ML Types
  EXPORT FromNumericFieldDS(DATASET(ML_Types.NumericField) cells,
                           Types.dimension_t insert_columns=0,
                           Types.value_t insert_value=0.0d) := FUNCTION
    Layout_Cell cvt_2_cell(ML_Types.NumericField lr) := TRANSFORM
      SELF.x              := lr.id;     // 1 based
      SELF.y              := lr.number; // 1 based
      SELF.v              := lr.value;
    END;
    d0 := PROJECT(cells, cvt_2_cell(LEFT));
    rslt := FromCells(d0, insert_columns, insert_value);
    RETURN rslt;
  END;

  // To ML Types
  ML_Types.NumericField cvt2NF(Layout_Cell cell) := TRANSFORM
    SELF.id               := cell.x;
    SELF.number           := cell.y;
    SELF.value            := cell.v;
  END;
  EXPORT FromPartDS(DATASET(Layout_Part) part_recs) :=
    PROJECT(FromPart2Cell(part_recs), cvt2NF(LEFT));
END;