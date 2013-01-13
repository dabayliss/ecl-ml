//void cblas_dgemm(const enum CBLAS_ORDER Order, const enum CBLAS_TRANSPOSE TransA,
//                 const enum CBLAS_TRANSPOSE TransB, const int M, const int N,
//                 const int K, const double alpha, const double *A,
//                 const int lda, const double *B, const int ldb,
//                 const double beta, double *C, const int ldc);
IMPORT PBblas.Types;
dimension_t := Types.dimension_t;
value_t     := Types.value_t;
matrix_t    := Types.matrix_t;

EXPORT matrix_t dgemm(BOOLEAN transposeA, BOOLEAN transposeB,
                      dimension_t M, dimension_t N, dimension_t K,
                      value_t alpha, matrix_t A, matrix_t B,
                      value_t beta, matrix_t C=[]) := BEGINC++
extern "C" {
#include <cblas.h>
}
#option library cblas
#body
   unsigned int lda = transposea==0 ? m  : k;
   unsigned int ldb = transposeb==0 ? k  : n;
   unsigned int ldc = m;
   __isAllResult = false;
   __lenResult = m * n * sizeof(double);
   double *result = new double[m * n];
   // populate if provided
   for(int i=0; i<m*n; i++) result[i] = (__lenResult==lenC) ?((double*)c)[i] :0.0;
   cblas_dgemm(CblasColMajor,
               transposea ? CblasTrans : CblasNoTrans,
               transposeb ? CblasTrans : CblasNoTrans,
               m, n, k, alpha,
               (const double *) a, lda,
               (const double *) b, ldb,
               beta, result, ldc);
   __result = (void *) result;
ENDC++;
