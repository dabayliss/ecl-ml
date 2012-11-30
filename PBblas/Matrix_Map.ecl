// Define processor grid template, and matrix mapping functions
IMPORT std.system.Thorlib;
IMPORT PBblas;
dimension_t := PBblas.Types.dimension_t;
partition_t := PBblas.Types.partition_t;

EXPORT Matrix_Map(dimension_t m_rows, dimension_t m_cols,
                  dimension_t f_b_rows=0, dimension_t f_b_cols=0)
                  := MODULE(PBblas.IMatrix_Map)
  SHARED nodes_available := Thorlib.nodes();
  SHARED this_node       := Thorlib.node();
  //
  EXPORT row_blocks   := IF(f_b_rows>0, ((m_rows-1) DIV f_b_rows) + 1, 1);
  EXPORT col_blocks   := IF(f_b_cols>0, ((m_cols-1) DIV f_b_cols) + 1, 1);
  SHARED block_rows   := f_b_rows;    // Need an IF here
  SHARED block_cols   := f_b_cols;    // Need an IF here
  //
  EXPORT matrix_rows  := m_rows;
  EXPORT matrix_cols  := m_cols;
  EXPORT partitions_used := row_blocks * col_blocks;
  EXPORT nodes_used   := MIN(nodes_available, partitions_used);
  // Functions.
  EXPORT row_block(dimension_t mat_row) := ((mat_row-1) DIV block_rows) + 1;
  EXPORT col_block(dimension_t mat_col) := ((mat_col-1) DIV block_cols) + 1;
  EXPORT assigned_part(dimension_t rb, dimension_t cb) := ((cb-1) * row_blocks) + rb;
  EXPORT assigned_node(partition_t p) := ((p-1) % nodes_used);
  EXPORT first_row(partition_t p)   := (((p-1)  %  row_blocks) * block_rows) + 1;
  EXPORT first_col(partition_t p)   := (((p-1) DIV row_blocks) * block_cols) + 1;
  EXPORT part_rows(partition_t p)   := MIN(matrix_rows-first_row(p)+1, block_rows);
  EXPORT part_cols(partition_t p)   := MIN(matrix_cols-first_col(p)+1, block_cols);
END;