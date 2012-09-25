//Take a dataset of cells for a partition and pack into a dense matrix.  Specify Row or Column major
//First row and first column are one based.
//Insert is used insert columns with a spacific value.  Typical use is building a matrix for a solver
//where the first column is an inserted column of 1 values for the intercept.
IMPORT PBblas.Types;
dimension_t := Types.dimension_t;
value_t := Types.value_t;
Layout_Cell := Types.Layout_Cell;
array_enum  := Types.array_enum;

EXPORT SET OF REAL8 makeR8Set(dimension_t r, dimension_t s,
                              dimension_t first_row, dimension_t first_col,
                              DATASET(Layout_Cell) D, array_enum layout,
                              dimension_t insert_columns,
                              value_t insert_value) := BEGINC++
    typedef struct {      // copy of Layout_Cell translated to C
      uint32_t x;
      uint32_t y;
      double v;
    } work1;
    #define Column_Major 1
    #body
    __lenResult = r * s * sizeof(double);
    __isAllResult = false;
    double * result = new double[r*s];
    __result = (void*) result;
    work1 *cell = (work1*) d;
    int cells = lenD / sizeof(work1);
    int i;
    int pos;
    for (i=0; i<m*n; i++) {
      result[i] = (  (layout==Column_Major && i DIV r < insert_columns)
                   ||(layout!=Column_Major && i DIV s < insert_columns)  )
                ? value   : 0.0;
    }
    int x, y;
    for (i=0; i<cells; i++) {
      x = cell[i].x - first_row;  // input co-ordinates are 1 based, x and y are zero based.
      y = cell[i].y + columns - first_column;
      if(x < 0 || x >= r) continue;   // cell does not belong
      if(y < 0 || y >= s) continue;
      pos = (layout==Column_Major) ?(y*r) + x   :(x*s) + y;
      result[pos] = cell[i].v;
    }
  ENDC++;