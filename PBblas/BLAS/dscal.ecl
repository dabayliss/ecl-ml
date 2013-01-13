// scale a vector
//void cblas_dscal(const int N, const double alpha, double *X, const int incX);
IMPORT PBblas.Types;
dimension_t := Types.dimension_t;
value_t     := Types.value_t;
matrix_t    := Types.matrix_t;

EXPORT matrix_t dscal(dimension_t N, value_t alpha, matrix_t X,
                      dimension_t incX) := BEGINC++
extern "C" {
#include <cblas.h>
}
#option library cblas
#body
  __isAllResult = false;
  __lenResult = n * sizeof(double);
  double *result = new double[n];
  memcpy(result, x, __lenResult);
  cblas_dscal(n, alpha, result, incx);;
  __result = (void*) result;
ENDC++;
