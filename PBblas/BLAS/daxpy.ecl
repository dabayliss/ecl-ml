//void cblas_daxpy(const int N, const double alpha, const double *X,
//                 const int incX, double *Y, const int incY);
IMPORT PBblas.Types;
dimension_t := Types.dimension_t;
value_t     := Types.value_t;
matrix_t    := Types.matrix_t;

EXPORT matrix_t daxpy(dimension_t N, value_t alpha, matrix_t x,
                      dimension_t incX, matrix_t Y, incY) := BEGINC++
extern "C" {
#include <cblas.h>
}
#option library cblas
#body
  __isAllResult = false;
  __lenResult = n * sizeof(double);
  double *result = new double[n];
  memcpy(result, y, __lenResult);
  cblas_daxpy(n, alpha, (double*)x, incx, result, incy);
  __result = (void*) result;
ENDC++;
