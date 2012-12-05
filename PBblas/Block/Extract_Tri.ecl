//Extract the upper triangular matrix or the lower triangular matrix
//from a composite.  Composites are produced by some factorizations.
//
IMPORT PBblas.Types;
matrix_t := Types.matrix_t;
dimension_t := Types.dimension_t;
Triangle := Types.Triangle;
Diagonal := Types.Diagonal;

EXPORT matrix_t Extract_Tri(dimension_t m, dimension_t n,
                            Triangle tri, Diagonal dt, matrix_t a) := BEGINC++
  #define UPPER 1
  #define UNIT_TRI 1
  #body
  int cells = m * n;
  __isAllResult = false;
  __lenResult = cells * sizeof(double);
  double *new_a = new double[cells];
  unsigned int r, c;    //row and column
  unsigned int sq_dim = (m < n) ? m  : n;
  for (int i=0; i<cells; i++) {
    r = i % m;
    c = i / m;
    if (r==c) new_a[i] = (dt==UNIT_TRI) ? 1.0  : ((double*)a)[i];
    else if (r > c) { // lower part
      new_a[i] = (tri==UPPER) ? 0.0  : ((double*)a)[i];
    } else {          // upper part
      new_a[i] = (tri==UPPER) ? ((double*)a)[i]  : 0.0;
    }
  }
  __result = (void*) new_a;
ENDC++;