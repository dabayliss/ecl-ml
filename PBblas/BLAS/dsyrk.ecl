//void cblas_dsyrk(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo,
//                 const enum CBLAS_TRANSPOSE Trans, const int N, const int K,
//                 const double alpha, const double *A, const int lda,
//                 const double beta, double *C, const int ldc);
// Implements symetric rank update.  C <- alpha A**T * A  + beta C (Transpose)
//or C <- alpha A * A**T  + beta C.  Triangular parameters says whether
//the update is upper or lower.  C is N by N

IMPORT PBblas.Types;
dimension_t := Types.dimension_t;
Triangle    := Types.Triangle;
value_t     := Types.value_t;
matrix_t    := Types.matrix_t;

EXPORT matrix_t dsyrk(Triangle tri, BOOLEAN transposeA,
            dimension_t N, dimension_t K,
            value_t alpha, matrix_t A,
            value_t beta, matrix_t C, BOOLEAN clear=FALSE) := BEGINC++
extern "C" {
#include <cblas.h>
}
#define UPPER 1
#option library cblas
#body
  __isAllResult = false;
  __lenResult = n * n * sizeof(double);
  double *new_c = new double[n*n];
  if (clear) {
    unsigned int pos = 0;
    for(unsigned int i=0; i<n; i++) {
      pos = i*n;  // pos is head of column
      for (unsigned int j=0; j<n; j++) {
        new_c[pos+j] = tri==UPPER ? i>=j ? ((double*)c)[pos+j]  : 0.0
                                  : i<=j ? ((double*)c)[pos+j]  : 0.0;
      }
    }
  } else memcpy(new_c, c, __lenResult);
  unsigned int lda = (transposea)  ? k  : n;
  cblas_dsyrk(CblasColMajor,
              tri==UPPER  ? CblasUpper  : CblasLower,
              transposea ? CblasTrans : CblasNoTrans,
              n, k, alpha, (const double *)a, lda, beta, new_c, n);
  __result = (void*) new_c;
ENDC++;
