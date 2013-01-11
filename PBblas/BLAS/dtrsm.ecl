//void cblas_dtrsm(const enum CBLAS_ORDER Order, const enum CBLAS_SIDE Side,
//                 const enum CBLAS_UPLO Uplo, const enum CBLAS_TRANSPOSE TransA,
//                 const enum CBLAS_DIAG Diag, const int M, const int N,
//                 const double alpha, const double *A, const int lda,
//                 double *B, const int ldb);
// Triangular matrix solver.
//  op( A )*X = alpha*B,   or   X*op( A ) = alpha*B; B is m x n
//
IMPORT PBblas.Types;
dimension_t := Types.dimension_t;
Triangle    := Types.Triangle;
Diagonal    := Types.Diagonal;
Side        := Types.Side;
value_t     := Types.value_t;
matrix_t    := Types.matrix_t;

EXPORT matrix_t dtrsm(Side side, Triangle tri,
                      BOOLEAN transposeA, Diagonal diag,
                      dimension_t M, dimension_t N,  dimension_t lda,
                      value_t alpha, matrix_t A, matrix_t B) := BEGINC++
extern "C" {
#include <cblas.h>
}
#define UPPER 1
#define AX 1
#define UNIT 1
#option library cblas
#body
  unsigned int ldb = m;
  __isAllResult = false;
  __lenResult = m * n * sizeof(double);
  double *new_b = new double[m*n];
  memcpy(new_b, b, __lenResult);
  cblas_dtrsm(CblasColMajor,
              side==AX ?  CblasLeft  : CblasRight,
              tri==UPPER  ? CblasUpper  : CblasLower,
              transposea ? CblasTrans : CblasNoTrans,
              diag==UNIT ? CblasUnit : CblasNonUnit,
              m, n, alpha, (const double *)a, lda, new_b, ldb);
  __result = (void*) new_b;
ENDC++;
