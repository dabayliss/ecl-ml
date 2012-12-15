//Extract the Upper or Lower triangular matrix from a composite.
IMPORT PBblas;
IMPORT PBblas.Block;
IMPORT PBblas.BLAS;
IMPORT PBblas.Types;
IMPORT PBblas.IMatrix_Map;
Layout_Part := Types.Layout_Part;
Triangle := Types.Triangle;
Upper:= Types.Triangle.Upper;
Lower:= Types.Triangle.Lower;
Diagonal := Types.Diagonal;
Types.matrix_t empty_mat := [];
dimension_t := Types.dimension_t;


EXPORT PB_Extract_Tri(Triangle tri, Diagonal dt,
                      IMatrix_Map map_a, DATASET(Layout_Part) A) := FUNCTION
  diag_in := SORTED(A(block_row = block_col), partition_id);
  non_diag := SORTED(A((tri=Upper AND block_row<block_col)
            OR (tri=Lower AND block_row>block_col)), partition_id);
  Layout_Part extractTriangle(Layout_Part part) := TRANSFORM
    SELF.mat_part := Block.Extract_Tri(part.part_rows, part.part_cols,
                                       tri, dt, part.mat_part);
    SELF := part;
  END;
  diag_out := SORTED(PROJECT(diag_in, extractTriangle(LEFT)), partition_id);
  rslt := MERGE(non_diag, diag_out, SORTED(node_id, partition_id), LOCAL);
  RETURN rslt;
END;
