IMPORT * FROM $;
EXPORT eig := MODULE

SHARED eig_comp := ENUM ( T = 1 );
EXPORT DATASET(Types.Element) QRalgorithm(DATASET(Types.Element) A, INTEGER iter) := FUNCTION

	//Alpha0 := DATASET([],Types.Element);	
	//Beta0 := DATASET([],Types.Element);	
	
	loopBody(DATASET( Types.MUElement) ds, UNSIGNED4 k) := FUNCTION

		T := Mat.MU.From(ds, eig_comp.T);
		QComp := Decomp.QComp(T);
		RComp := Decomp.RComp(T);
		T1 := Mat.Mul(Thin(RComp), Thin(QComp));
		
	RETURN Mat.MU.To(Thin(T1), eig_comp.T);
  END;
	
	RETURN LOOP(Mat.Mu.To(A, eig_comp.T), iter, loopBody(ROWS(LEFT),COUNTER));
	
END;

EXPORT TComp(DATASET(Types.Element) matrix, INTEGER iter=200) := Mat.MU.From(QRalgorithm(matrix, iter), eig_comp.T);
//EXPORT VComp(DATASET(Types.Element) matrix) := Mat.MU.From(TV(matrix), l_comp.V)(y>1 AND y<Has(matrix).Dimension);


END;