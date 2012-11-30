//Transpose a dense matrix using PB BLAS routines
IMPORT PBblas;
IMPORT PBblas.Types;
IMPORT PBblas.IMatrix_Map;
Part := Types.Layout_Part;
EXPORT Trans := MODULE
  EXPORT TranMap(IMatrix_Map a_map) := FUNCTION
    RETURN PBblas.Matrix_Map(a_map.matrix_cols, a_map.matrix_rows,
                             a_map.part_cols(1),a_map.part_rows(1));
  END;

  EXPORT DATASET(Part) matrix(IMatrix_Map a_map, DATASET(Part) a) := FUNCTION
    c_map := TranMap(a_map);
    RETURN PBblas.PB_dtran(a_map, c_map, 1.0, a);
  END;
END;
