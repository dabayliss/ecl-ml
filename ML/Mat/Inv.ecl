IMPORT * FROM $;
 
Inverse(DATASET(Types.Element) matrix) := FUNCTION
	dim := Has(matrix).Dimension;
	lum := LU.Decompose(matrix);
	l := LU.L_component(lum);
	u := LU.U_component(lum);
	i_m := Identity(dim);
	fsub := LU.f_sub(l, i_m);
	matrix_inverse := LU.b_sub(u, fsub);
	RETURN matrix_inverse;
END;
EXPORT Inv(DATASET(Types.Element) matrix) := IF(Det(matrix)=0, DATASET([],Types.Element), Inverse(matrix) );
