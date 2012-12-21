// Test the triangular solver.  Can be left or right, and transposed.
IMPORT PBblas;
IMPORT PBblas.BLAS;
IMPORT PBblas.LAPACK;
IMPORT PBblas.Types;
IMPORT ML.DMAT;
matrix_t := Types.matrix_t;
Triangle := Types.Triangle;
Diagonal := Types.Diagonal;
Upper  := Triangle.Upper;
Lower  := Triangle.Lower;
Matrix_Map :=  PBblas.Matrix_Map;
Layout_Part := Types.Layout_Part;
Side := Types.Side;

map_1  := Matrix_Map(8, 8, 8, 8);
map_2  := Matrix_Map(8, 8, 3, 3);


matrix_t Pre_A := [1.0, 2.0, 3.0, 1.0, 4.0, 5.0, 7.0, 6.0,
                   2.0, 2.0, 3.0, 4.0, 1.0, 7.0, 9.0, 1.0,
                   3.0, 3.0, 1.0, 2.0, 2.0, 6.0, 1.0, 2.0,
                   1.0, 4.0, 2.0, 4.0, 3.0,11.0, 7.0,13.0,
                   4.0, 1.0, 2.0, 3.0, 1.0, 4.0, 5.0, 7.0,
                   7.0, 1.0, 3.0, 9.0,13.0, 3.0, 7.0, 9.0,
                   8.0, 3.0, 1.0, 4.0, 5.0, 7.0, 6.0, 2.0,
                   5.0,11.0, 3.0, 5.0, 7.0,13.0, 2.0, 7.0];
A := BLAS.dgemm(TRUE, FALSE,
             8, 8, 8, 1.0, // M, N, K, alpha
             Pre_A, Pre_A, 0.0);    // Make a positive definite symetric matrix of full rank
X := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
      1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
      1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
      1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
      1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
      1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
      1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
      1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0];
E := BLAS.dgemm(FALSE, FALSE,
             8, 8, 8, 1.0,
             A, X, 0.0);
F := BLAS.dgemm(FALSE, FALSE,
             8, 8, 8, 1.0,
             X, A, 0.0);

a1 := DATASET([{0,1,1,1,1,8,1,8, A}], Types.Layout_Part);
x1 := DATASET([{0,1,1,1,1,8,1,8, X}], Types.Layout_Part);
e1 := DATASET([{0,1,1,1,1,8,1,8, E}], Types.Layout_Part);
f1 := DATASET([{0,1,1,1,1,8,1,8, F}], Types.Layout_Part);

a_cells := DMAT.Converted.FromPart2Cell(a1);
e_cells := DMAT.Converted.FromPart2Cell(e1);
f_cells := DMAT.Converted.FromPart2Cell(f1);



// Run 1 partition
C_L1 := PBblas.PB_dpotrf(Lower, map_1, a1);
C_S1 := PBblas.PB_dtrsm(Side.Ax, Lower, FALSE, Diagonal.NotUnitTri,
                      1.0, map_1, C_L1, map_1, E1);
C_T1 := PBblas.PB_dtrsm(Side.Ax, Upper, TRUE, Diagonal.NotUnitTri,
                      1.0, map_1, C_L1, map_1, C_S1);
test_1 := PBblas.Tests.DiffReport.Compare_Parts('Ax Solve, Single, Cholesky', x1, C_T1);

E_LU1:= PBBlas.PB_dgetrf(map_1, a1);
E_S1 := PBblas.PB_dtrsm(Side.Ax, Lower, FALSE, Diagonal.UnitTri,
                      1.0, map_1, E_LU1, map_1, E1);
E_T1 := PBblas.PB_dtrsm(Side.Ax, Upper, FALSE, Diagonal.NotUnitTri,
                      1.0, map_1, E_LU1, map_1, E_S1);
test_2 := PBblas.Tests.DiffReport.Compare_Parts('Ax Solve, Single, LU', x1, E_T1);

F_LU1:= E_LU1;
F_S1 := PBblas.PB_dtrsm(Side.xA, Upper, FALSE, Diagonal.NotUnitTri,
                      1.0, map_1, F_LU1, map_1, F1);
F_T1 := PBblas.PB_dtrsm(Side.xA, Lower, FALSE, Diagonal.UnitTri,
                      1.0, map_1, F_LU1, map_1, F_S1);
test_3:=PBblas.Tests.DiffReport.Compare_Parts('xA Solve, Single, LU', x1, F_T1);

// Run 2 partitions
a2 := DMAT.Converted.FromCells(map_2, a_cells);
E2 := DMAT.Converted.FromCells(map_2, e_cells);
F2 := DMAT.Converted.FromCells(map_2, f_cells);
C_U2  := PBblas.PB_dpotrf(Upper, map_2, a2);
C_S2  := PBblas.PB_dtrsm(Side.Ax, Lower, TRUE, Diagonal.NotUnitTri,
                      1.0, map_2, C_U2, map_2, E2);
C_T2  := PBblas.PB_dtrsm(Side.Ax, Upper, FALSE, Diagonal.NotUnitTri,
                      1.0, map_2, C_U2, map_2, C_S2);
test_4:= PBblas.Tests.DiffReport.Compare_Parts('Ax Solve, Multiple, Cholesky', x1, C_T2);

E_LU2 := PBblas.PB_dgetrf(map_2, a2);
E_S2  := PBblas.PB_dtrsm(Side.Ax, Lower, FALSE, Diagonal.UnitTri,
                      1.0, map_2, E_LU2, map_2, E2);
E_T2  := PBblas.PB_dtrsm(Side.Ax, Upper, FALSE, Diagonal.NotUnitTri,
                      1.0, map_2, E_LU2, map_2, E_S2);
test_5:= PBblas.Tests.DiffReport.Compare_Parts('Ax Solve, Multiple, LU', x1, E_T2);

F_LU2 := E_LU2;
F_S2  := PBblas.PB_dtrsm(Side.xA, Upper, FALSE, Diagonal.NotUnitTri,
                      1.0, map_2, F_LU2, map_2, F2);
F_T2  := PBblas.PB_dtrsm(Side.xA, Lower, FALSE, Diagonal.UnitTri,
                      1.0, map_2, F_LU2, map_2, F_S2);
test_6:= PBblas.Tests.DiffReport.Compare_Parts('xA Solve, Multiple, LU', x1, F_T2);

EXPORT Solve := test_1 + test_2 + test_3 + test_4 + test_5 + test_6;