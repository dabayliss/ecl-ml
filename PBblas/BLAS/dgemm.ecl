//void cblas_dgemm(const enum CBLAS_ORDER Order, const enum CBLAS_TRANSPOSE TransA,
//                 const enum CBLAS_TRANSPOSE TransB, const int M, const int N,
//                 const int K, const double alpha, const double *A,
//                 const int lda, const double *B, const int ldb,
//                 const double beta, double *C, const int ldc);
IMPORT PBblas.Types;
dimension_t := Types.dimension_t;
array_enum  := Types.array_enum;
matrix_t    := Types.matrix_t;

EXPORT matrix_t dgemm(array_enum layout, BOOLEAN transposeA, BOOLEAN transposeB,
                      dimension_t M, dimension_t N, dimension_t K,
                      REAL8 alpha, SET OF REAL8 A, dimension_t lda,
                      SET OF REAL8 B, dimension_t ldb,
                      REAL8 beta, SET OF REAL8 C, dimension_t ldc) := BEGINC++
#include <cblas.h>
#define COLUMN_MAJOR 1    // See PBblas Types array_enum
#option library blas
#body
   __isAllResult = false;
   __lenResult = m * n * sizeof(double);
   double *result = new double[m * n];
   // populate if provided
   if (__lenResult==lenC) for(int i=0; i<m*n; i++) result[i] = ((double*)c)[i];
   cblas_dgemm((layout==COLUMN_MAJOR) ? CblasColMajor  : CblasRowMajor,
               transposea ? CblasTrans : CblasNoTrans,
               transposeb ? CblasTrans : CblasNoTrans,
               m, n, k, alpha,
               (const double *) a, lda,
               (const double *) b, ldb,
               beta, result, ldc);
   __result = (void *) result;
ENDC++;
