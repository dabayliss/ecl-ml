// Pure dense matrix substraction based upon PB-BLAS
IMPORT PBblas;
IMPORT PBblas.Types;
Part := Types.Layout_Part;
IMatrix_Map := PBblas.IMatrix_Map;
EXPORT DATASET(Part) Sub(IMatrix_Map m_map, DATASET(Part) minuend,
                         IMatrix_Map s_map, DATASET(Part) subtrahend) := FUNCTION
  RETURN PBblas.PB_daxpy(-1.0, subtrahend, minuend);
END;
