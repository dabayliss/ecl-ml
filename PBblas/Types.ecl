// Types for the Parellel Block Basic Linear Algebra Sub-programs support
EXPORT Types := MODULE
  EXPORT dimension_t  := UNSIGNED4;     // WARNING: do not change with out changing C++ attributes
  EXPORT partition_t  := UNSIGNED2;
  EXPORT node_t       := UNSIGNED2;
  EXPORT value_t      := REAL8;
  EXPORT matrix_t     := SET OF REAL8;
  EXPORT array_enum   := ENUM(UNSIGNED1, Column_Major=1, Row_Major=2);

  // Sparse
  EXPORT Layout_Cell  := RECORD   // WARNING:  Do not change without changing C++ attributes
    dimension_t     x;    // 1 based index position
    dimension_t     y;    // 1 based index position
    value_t         v;
  END;
  // Dense
  EXPORT Layout_Part  := RECORD
    partition_t     partition_id;
    node_t          node_id;
    partition_t     destination_partition_id;   // usually zero
    node_t          destination_node_id;        // usually zero
    dimension_t     block_row;
    dimension_t     block_col;
    dimension_t     begin_row;
    dimension_t     end_row;
    dimension_t     begin_col;
    dimension_t     end_col;
    array_enum      array_layout;
    matrix_t        mat_part;
  END;
END;