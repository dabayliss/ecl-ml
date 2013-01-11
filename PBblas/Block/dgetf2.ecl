//DGETF2 computes the LU factorization of a matrix A.  Similar to LAPACK routine
//of same name.  Result matrix holds both Upper and Lower triangular matrix, with
//lower matrix diagonal implied since it is a unit triangular matrix.
//This version does not permute the rows.
//
//This routine would be better if dlamch were available to determine safe min
//
IMPORT PBblas.Types;
IMPORT PBblas.Constants;
dimension_t := Types.dimension_t;
Triangle    := Types.Triangle;
matrix_t    := Types.matrix_t;
Not_PositiveDefZ := Constants.Not_PositiveDefZ;
Not_PositiveDef  := Constants.Not_PositiveDef;

EXPORT matrix_t dgetf2(dimension_t m, dimension_t n, matrix_t a,
                       UNSIGNED4 errCode=Not_PositiveDefZ,
                       VARSTRING errMsg=Not_PositiveDef) := BEGINC++
extern "C" {
#include <cblas.h>
}
#include <math.h>
#body
  //double sfmin = dlamch('S');   // get safe minimum
  unsigned int cells = m*n;
  __isAllResult = false;
  __lenResult = cells * sizeof(double);
  double *new_a = new double[cells];
  memcpy(new_a, a, __lenResult);
  double akk;
  unsigned int i, j, k;
  unsigned int diag, vpos, wpos, mpos;
  unsigned int sq_dim = (m < n) ? m  : n;
  for (k=0; k<sq_dim; k++) {
    diag = (k*m) + k;     // diag cell
    vpos = diag + 1;      // top cell of v vector
    wpos = diag + m;      // left cell of w vector
    mpos = diag + m + 1;  //upper left of sub-matrix to update
    akk = new_a[diag];
    if (akk == 0.0) rtlFail(errcode, errmsg); // need to permute
    //Ideally, akk should be tested against sfmin, and dscal used
    // to update the vector for the L cells.
    for (i=vpos; i<vpos+m-k-1; i++) new_a[i] = new_a[i]/akk;
    //Update sub-matrix
    if (k < sq_dim - 1) {
      cblas_dger(CblasColMajor,
                 m-k-1, n-k-1, -1.0,  // sub-matrix dimensions
                 (new_a+vpos), 1, (new_a+wpos), m, (new_a+mpos), m);
    }
  }
  __result = (void*) new_a;
ENDC++;
