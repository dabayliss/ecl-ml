//DPOTF2 computes the Cholesky factorization of a real symmetric
// positive definite matrix A.
//The factorization has the form
// A = U**T * U ,  if UPLO = 'U', or
// A = L  * L**T,  if UPLO = 'L',
// where U is an upper triangular matrix and L is lower triangular.
// This is the unblocked version of the algorithm, calling Level 2 BLAS.
//

IMPORT PBblas.Types;
dimension_t := Types.dimension_t;
array_enum  := Types.array_enum;
Triangle    := Types.Triangle;
matrix_t    := Types.matrix_t;

EXPORT matrix_t dpotf2(array_enum layout, Triangle tri,
                       dimension_t r, matrix_t A) := BEGINC++
#include <cblas.h>
#include <math.h>
#define COLUMN_MAJOR 1    // See PBblas Types array_enum
#define UPPER_TRIANGLE 1  // See PBblas Types Triangle
#option library blas
#body
  unsigned int cells = r*r;
  __isAllResult = false;
  __lenResult = cells * sizeof(double);
  double *new_a = new double[cells];
  memcpy(new_a, a, __lenResult);
  //Ignore errors for now
  double ajj;
  unsigned int diag, a_pos, x_pos, y_pos;
  unsigned int col_step = (layout==COLUMN_MAJOR) ? r  : 1;  // between columns
  unsigned int row_step = (layout==COLUMN_MAJOR) ? 1  : r;  // between rows
  unsigned int x_step = (tri==UPPER_TRIANGLE)  ? row_step  : col_step;
  unsigned int y_step = (tri==UPPER_TRIANGLE)  ? col_step  : row_step;
  for (unsigned int j=0; j<r; j++) {
    diag = (j * r) + j;    // diagonal
    x_pos = j * ((tri==UPPER_TRIANGLE) ? col_step  : row_step);
    a_pos = (j+1) * ((tri==UPPER_TRIANGLE) ? col_step  : row_step);
    y_pos = diag + y_step;
    ajj = new_a[diag] - cblas_ddot(j, (new_a+x_pos), x_step, (new_a+x_pos), x_step);
    // if ajj is 0 or NaN, then error
    ajj = sqrt(ajj);
    new_a[diag] = ajj;
    if ( j < r-1) {
      cblas_dgemv((layout==COLUMN_MAJOR) ? CblasColMajor  : CblasRowMajor,
                  (tri==UPPER_TRIANGLE)  ? CblasTrans     : CblasNoTrans,
                   j, r-1-j, -1.0,                // M, N, alpha
                   (new_a+a_pos), r,              //A
                   (new_a+x_pos), x_step,         //X
                   1.0, (new_a+y_pos), y_step);   // beta and Y
      cblas_dscal(r-1-j, 1.0/ajj, (new_a+y_pos), y_step);
    }
  }
  __result = (void*) new_a;
ENDC++;