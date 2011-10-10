IMPORT * FROM $;

EXPORT Inv(DATASET(Types.Element) matrix) := FUNCTION
	dim := Has(matrix).Dimension;
	lum := LU.Decompose(matrix);
	l := LU.L_component(lum);
	u := LU.U_component(lum);
	i_m := Identity(dim);
	fsub := LU.f_sub(l, i_m);
	inverse_matrix := LU.b_sub(u, fsub);
	RETURN inverse_matrix;
END;
