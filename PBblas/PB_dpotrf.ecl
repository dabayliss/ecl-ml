// Implements Cholesky factorization of A = U**T * U if Triangular.Upper
//or A = L * L**T if Triangualr.Lower is requested.
// The matrix A must be symmetric positive definite.
IMPORT PBblas.Types;
IMPORT PBblas.IMatrix_Map;
IMPORT PBBlas.BLAS;
Part := Types.Layout_Part;
Upper:= Types.Triangle.Upper;
Lower:= Types.Triangle.Lower;

EXPORT PB_dpotrf(Types.Triangle tri, IMatrix_Map map_a, DATASET(Part) A) := FUNCTION
  // LOOP body
  loopBody(DATASET(Part) parts, UNSIGNED4 c) := FUNCTION
    // Select diagonal block, use dpotf2 in PROJECT to produce L11
    // Use PB_DTRSM with L11 get D21 (D12)
    // Use PB_SYRK with L21(L12) to get L22
    RETURN parts;
  END;
  // Drop out parts that are not needed
  workParts := A((tri=Upper AND block_row>=block_col) OR
                 (tri=Lower AND block_col>=block_row));
  //
  triangleParts := LOOP(workParts, map_a.row_blocks,
                       COUNTER>LEFT.block_row OR COUNTER>LEFT.block_col,
                       loopBody(ROWS(LEFT), COUNTER));
  // add in zero parts
  RETURN A;
END;