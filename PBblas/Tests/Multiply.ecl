// Tests for the multiplication.  Compares single block results as
//the starndard against multi-block.
// alpha AB + beta C is the function.  A and B could be transposed.
IMPORT PBblas;
IMPORT PBblas.Tests;
IMPORT PBblas.Types;
IMPORT ML.DMAT;
Layout_Cell := Types.Layout_Cell;

// Generate test data
W_Rec := RECORD
  STRING1 x:= '';
END;
W0 := DATASET([{' '}], W_Rec);
Layout_Cell gen(UNSIGNED4 c, UNSIGNED4 NumRows, REAL8 v):=TRANSFORM
  SELF.x := ((c-1)  %  NumRows) + 1;
  SELF.y := ((c-1) DIV NumRows) + 1;
  SELF.v := v;
END;
REAL8 F_A(UNSIGNED4 c) := 3.0*c*c -5.0*c + 50.0;
map_11x8_1  := PBblas.Matrix_Map(11, 8, 11, 8);
map_11x8_9  := PBblas.Matrix_Map(11, 8, 4, 3);
a_cells := NORMALIZE(W0, 11*8, gen(COUNTER, 11, F_A(COUNTER)));
a1 := DMAT.Converted.FromCells(map_11x8_1, a_cells);
a9 := DMAT.Converted.FromCells(map_11x8_9, a_cells);

c_cells := NORMALIZE(W0, 64, gen(COUNTER, 8, 1));
map_8x8_1 := PBblas.Matrix_Map(8, 8, 8, 8);
map_8x8_9 := PBblas.Matrix_Map(8, 8, 3, 3);
c1 := DMAT.Converted.FromCells(map_8x8_1, c_cells);
c9 := DMAT.Converted.FromCells(map_8x8_9, c_cells);

b_cells := NORMALIZE(W0, 8*8, gen(COUNTER, 8, COUNTER));
b1 := DMAT.Converted.FromCells(map_8x8_1, b_cells);
b9 := DMAT.Converted.FromCells(map_8x8_9, b_cells);

// 2.0 AB 
t_2AB_0_1 := PBblas.PB_dgemm(FALSE, FALSE, 
                             2.0, map_11x8_1, a1, map_8x8_1, b1, 
                             map_11x8_1);
t_2AB_0_9 := PBblas.PB_dgemm(FALSE, FALSE,
                             2.0, map_11x8_9, a9, map_8x8_9, b9,
                             map_11x8_9);
test1 := Tests.DiffReport.Compare_Parts('2.0 * AB', t_2AB_0_1, t_2AB_0_9);

// 1.0 ABt
t_ABt_0_1 := PBblas.PB_dgemm(FALSE, TRUE, 
                             1.0, map_11x8_1, a1, map_8x8_1, b1, 
                             map_11x8_1);
t_ABt_0_9 := PBblas.PB_dgemm(FALSE, TRUE,
                             1.0, map_11x8_9, a9, map_8x8_9, b9,
                             map_11x8_9);
test2 := Tests.DiffReport.Compare_Parts('ABt', t_ABt_0_1, t_ABt_0_9);

// - BtB + C
t_BtB_C_1 := PBblas.PB_dgemm(TRUE, FALSE,
                             -1.0, map_8x8_1, b1, map_8x8_1, b1,
                             map_8x8_1, c1, 1.0);
t_BtB_C_9 := PBblas.PB_dgemm(TRUE, FALSE,
                             -1.0, map_8x8_9, b9, map_8x8_9, b9,
                             map_8x8_9, c9, 1.0);
test3 := Tests.DiffReport.Compare_Parts('C - BtB', t_BtB_C_1, t_BtB_C_9);

// Report
rpt := test1 + test2 + test3;
EXPORT Multiply := rpt;
