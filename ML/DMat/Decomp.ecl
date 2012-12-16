// Factor a matrix with either Cholesky or LU.  This is the
//dense matrix version using PB-BLAS attributes.  In the style of
//Mat.Decomp attribute but with the options exposed.
IMPORT PBblas;
IMPORT PBblas.Types;
IMatrix_Map := PBblas.IMatrix_Map;
Layout_Part := Types.Layout_Part;
Triangle    := Types.Triangle;
Side        := Types.Side;
Diagonal    := Types.Diagonal;


EXPORT Decomp := MODULE
  // Solve with back substitution and a triangular matrix.  Can accept
  //a composite matrix as provided by LU
  EXPORT DATASET(Layout_Part) b_sub(IMatrix_Map u_map, DATASET(Layout_Part) U,
               IMatrix_Map b_map, DATASET(Layout_Part) B,
               Side s=Side.Ax, Diagonal diag=Diagonal.NotUnitTri,
               BOOLEAN transposeA=FALSE)
       := PBblas.PB_dtrsm(s, Triangle.Upper, transposeA, diag, 1.0,
                          u_map, U, b_map, B);
  // Solve with forward substitution and a triangular matrix.  Can accept
  //a composite matrix as provided by LU, but you must set diagonal to
  //Diagonal.UnitTri
  EXPORT DATASET(Layout_Part) f_sub(IMatrix_Map l_map, DATASET(Layout_Part) L,
               IMatrix_Map b_map, DATASET(Layout_Part) B,
               Side s=Side.Ax, Diagonal diag=Diagonal.NotUnitTri,
               BOOLEAN transposeA=FALSE)
       := PBblas.PB_dtrsm(s, Triangle.Lower, transposeA, diag, 1.0,
                          l_map, L, b_map, B);
  // Cholesky factorization, default is to return a Lower triangle
  EXPORT DATASET(Layout_Part) Cholesky(IMatrix_Map a_map, DATASET(Layout_Part) A,
               Triangle tri=Triangle.Lower) := PBblas.PB_dpotrf(tri, a_map, A);
  // LU Factorization.  Returns a composite
  EXPORT DATASET(Layout_Part) LU(IMatrix_Map a_map, DATASET(Layout_Part) A)
       := PBblas.PB_dgetrf(a_map, A);
  //Extract the lower triabe form a composite
  EXPORT DATASET(Layout_Part) LComp(IMatrix_Map a_map, DATASET(Layout_Part) A)
       := PBblas.PB_Extract_Tri(Triangle.Lower, Diagonal.UnitTri, a_map, A);
  //Extract the upper triangle form a composite
  EXPORT DATASET(Layout_Part) UComp(IMatrix_Map a_map, DATASET(Layout_Part) A)
       := PBblas.PB_Extract_Tri(Triangle.Upper, Diagonal.NotUnitTri, a_map, A);
  //
END;
