//Pure dense matrix scalar multiply using PB BLAS
IMPORT PBblas;
IMPORT PBblas.Types;
Part := Types.Layout_Part;
t_value := Types.value_t;
IMatrix_Map := PBblas.IMatrix_Map;

EXPORT DATASET(Part) Scale(IMatrix_Map a_map, t_value alpha,
                           DATASET(Part) a) := FUNCTION
  RETURN PBblas.PB_dscal(alpha, a);
END;