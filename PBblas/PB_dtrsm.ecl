// Partitioned block parallel triangular matrix solver.
//  Ax = B or xA = B
// A is is a square triangular matrix, x and B have the same dimensions.
//Partially based upon an approach discussed by MJ DAYDE, IS DUFF, AP CERFACS.
// A Parallel Block implementation of Level-3 BLAS for MIMD Vector Processors
// ACM Tran. Mathematical Software, Vol 20, No 2, June 1994 pp 178-193
//and other papers about PB-BLAS by Choi and Dongarra
IMPORT PBblas;
IMPORT PBblas.Constants;
IMPORT PBblas.Types;
IMPORT PBblas.BLAS;
IMPORT std.system.Thorlib;
value_t   := Types.value_t;
matrix_t  := Types.matrix_t;
Triangle  := Types.Triangle;
Lower     := Types.Triangle.Lower;
Upper     := Types.Triangle.Upper;
Diagonal  := Types.Diagonal;
Side      := Types.Side;
Part      := Types.Layout_Part;
Target    := Types.Layout_Target;
Dimension := Types.dimension_t;
Distribution_Error := PBblas.Constants.Distribution_Error;
Dimension_Incompat := PBblas.Constants.Dimension_Incompat;
Not_Square         := PBblas.Constants.Not_Square;
BaseTerm := 1;
RightTerm := 3;
LeftTerm := 2;

EXPORT PB_dtrsm(Side s, Triangle tri, BOOLEAN transposeA, Diagonal diag,
                value_t alpha,
                PBblas.IMatrix_Map a_map, DATASET(Part) rawA,
                PBblas.IMatrix_Map b_map, DATASET(Part) inB) := FUNCTION
  // Fix transpose of A if required.  This should not be required with more complex
  //conditions.
  inA := IF(transposeA, PBBlas.PB_dtran(a_map, a_map, 1.0, rawA), rawA);
  // First verify compatible maps
  ab_ok := a_map.matrix_cols=b_map.matrix_rows AND a_map.col_blocks=b_map.row_blocks;
  ba_ok := b_map.matrix_cols=a_map.matrix_rows AND b_map.col_blocks=a_map.row_blocks;
  a_sq  := a_map.matrix_rows=a_map.matrix_cols AND a_map.row_blocks=a_map.col_blocks;
  compatible:= IF(s=Side.Ax, ab_ok, ba_ok);
  a_checked := ASSERT(inA, ASSERT(compatible, Dimension_Incompat, FAIL),
                           ASSERT(a_sq, Not_Square, FAIL));
  b_DistChk := ASSERT(inB, node_id=Thorlib.node(), Constants.Distribution_Error, FAIL);
  b_checked := SORTED(B_DistChk, partition_id, LOCAL, ASSERT);
  // definitions for condition alias
  Upper_xA := s=Side.xA AND tri=Upper;
  Upper_Ax := s=Side.Ax AND tri=Upper;
  Lower_xA := s=Side.xA AND tri=Lower;
  Lower_Ax := s=Side.Ax AND tri=Lower;
  // Loop body, by diagonal, right to left for upper and left to right for lower
  loopBody(DATASET(Part) parts, UNSIGNED4 loop_c) := FUNCTION
    rght2lft:= IF(tri=Upper, s=Side.Ax, s=Side.xA);
    rc_pos  := IF(rght2lft, 1 + a_map.row_blocks - loop_c, loop_c);
    remaining := a_map.row_blocks - loop_c;  // Rows or Columns same
    // Solve the B blocks for diag co-efficient entry
    Part solveBlock(Part b_rec, Part a_rec) := TRANSFORM
      SELF.mat_part := BLAS.dtrsm(s, tri, FALSE, diag,
                                  b_map.part_rows(b_rec.partition_id),
                                  b_map.part_cols(b_rec.partition_id),
                                  a_map.part_rows(a_rec.partition_id),
                                  alpha, a_rec.mat_part, b_rec.mat_part);
      SELF := b_rec;
    END;
    // for solve, only diag coeff.  Transpose same as no transpose.
    solved := JOIN(parts, a_checked(block_row=rc_pos AND block_col=rc_pos),
                      (s=Side.Ax AND LEFT.block_row=RIGHT.block_row)
                   OR (s=Side.xA AND LEFT.block_col=RIGHT.block_col),
                   solveBlock(LEFT, RIGHT), LOOKUP);
    // Base parts stay in place, just need routing for transform
    Target prepBase(Part base) := TRANSFORM
      SELF.t_part_id  := base.partition_id;
      SELF.t_node_id  := base.node_id;
      SELF.t_block_row:= base.block_row;
      SELF.t_block_col:= base.block_col;
      SELF.t_term     := BaseTerm;
      SELF            := base;
    END;
    //Solved blocks not in update, loop filter has removed prior solves
    parts4update := parts(  (s=Side.Ax AND block_row <> rc_pos)
                         OR (s=Side.xA AND block_col <> rc_pos)  );
    need_upd := PROJECT(parts4update, prepBase(LEFT));
    //Replicate the solved blocks up or down for Ax or left or right for xA
    //or co-efficient blocks to the other columns in the row or rows in the
    //column.  Brings the newly solved X partition and the co-efficient
    //together to update the remaining sum value.
    Target repPart(Part inPart, Dimension repl, BOOLEAN isA) := TRANSFORM
      row_base          := IF(Lower_Ax AND NOT isA, rc_pos, 0);
      col_base          := IF(Upper_xA AND NOT isA, rc_pos, 0);
      row_use_repl      := IF(s=Side.xA, isA, NOT isA);
      col_use_repl      := IF(s=Side.Ax, isA, NOT isA);
      t_row             := IF(row_use_repl, repl+row_base, inPart.block_row);
      t_col             := IF(col_use_repl, repl+col_base, inPart.block_col);
      t_part            := b_map.assigned_part(t_row, t_col);
      SELF.t_part_id    := t_part;
      SELF.t_node_id    := b_map.assigned_node(t_part);
      SELF.t_block_row  := t_row;
      SELF.t_block_col  := t_col;
      SELF.t_term		:= MAP(isA AND s=Side.Ax	=> LeftTerm,
                           isA                => RightTerm,
                           s=Side.Ax          => RightTerm,
                           LeftTerm);
      SELF              := inPart;
    END;
    s0_repl  := NORMALIZE(solved, remaining, repPart(LEFT, COUNTER, FALSE));
    replSolv := SORT(DISTRIBUTE(s0_repl, t_node_id), t_part_id, LOCAL);
    neededCf := a_checked((Upper_Ax AND block_col=rc_pos AND block_row<rc_pos)
                       OR (Lower_Ax AND block_col=rc_pos AND block_row>rc_pos)
                       OR (Upper_xA AND block_row=rc_pos AND block_col>rc_pos)
                       OR (Lower_xA AND block_row=rc_pos AND block_col<rc_pos));
    c0_repl  := NORMALIZE(neededCf, a_map.col_blocks, repPart(LEFT, COUNTER, TRUE));
    replCoef := SORT(DISTRIBUTE(c0_repl, t_node_id), t_part_id, LOCAL);
    // Update the matrix
    Target updatePart(DATASET(Target) blocks) := TRANSFORM
      matrix_t EmptyMat := [];
      have_lft:= EXISTS(blocks(t_term = LeftTerm));
      have_rgt:= EXISTS(blocks(t_term = RightTerm));
      do_mult := have_lft AND have_rgt;
      have_b  := EXISTS(blocks(t_term=BaseTerm));
      b_set   := IF(have_b, blocks(t_term=BaseTerm)[1].mat_part, EmptyMat);
      lft_set := blocks(t_term=LeftTerm)[1].mat_part;
      lft_cols:= blocks(t_term=LeftTerm)[1].part_cols;
      rgt_set := blocks(t_term=RightTerm)[1].mat_part;
      part_id := blocks[1].t_part_id;   //all records have same value
      SELF.node_id  := blocks[1].t_node_id; // all records have the same
      SELF.partition_id := part_id; // all records have the same
      SELF.block_row  := blocks[1].t_block_row;
      SELF.block_col  := blocks[1].t_block_col;
      SELF.first_row  := b_map.first_row(part_id);
      SELF.part_rows  := b_map.part_rows(part_id);
      SELF.first_col  := b_map.first_col(part_id);
      SELF.part_cols  := b_map.part_cols(part_id);
      SELF.mat_part   := IF(do_mult,
                            BLAS.dgemm(FALSE, FALSE,
                                    b_map.part_rows(part_id),   // M
                                    b_map.part_cols(part_id),   // N
                                    lft_cols,                   // K
                                    -1.0, lft_set, rgt_set, 1.0, b_set),
                            b_set);
      SELF.t_node_id  := blocks[1].t_node_id;
      SELF.t_part_id  := blocks[1].t_part_id;
      SELF.t_block_row:= blocks[1].t_block_row;
      SELF.t_block_col:= blocks[1].t_block_col;
      SELF.t_term     := blocks[1].t_term;
    END;
    inpSet := [need_upd, replCoef, replSolv];
    updated := JOIN(inpSet,
                    LEFT.t_node_id=RIGHT.t_node_id AND
                    LEFT.t_part_id=RIGHT.t_part_id,
                    updatePart(ROWS(LEFT)), SORTED(t_node_id, t_part_id), MOFN(1));
    // assemble the revised parts
    dist_updated := DISTRIBUTE(PROJECT(updated, Part), node_id);
    sd_updated := SORT(dist_updated, partition_id, LOCAL);
    rslt := sd_updated & solved;
    RETURN rslt;
  END;  // loopBody
  // Run the solver
  x := LOOP(b_checked, a_map.row_blocks,  // A is square, so xA and Ax same count
            (Upper_Ax AND 1 + a_map.row_blocks - COUNTER >= LEFT.block_row) OR
            (Lower_Ax AND COUNTER <= LEFT.block_row) OR
            (Upper_xA AND COUNTER <= LEFT.block_col) OR
            (Lower_xA AND 1 + a_map.col_blocks - COUNTER >= LEFT.block_col),
            loopBody(ROWS(LEFT), COUNTER));
  RETURN SORT(DISTRIBUTE(x, node_id), partition_id, LOCAL);
END;