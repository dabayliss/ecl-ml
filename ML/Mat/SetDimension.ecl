IMPORT Types FROM ML.Mat;
EXPORT SetDimension(DATASET(Types.Element) A, Types.t_Index I, Types.t_Index J) := 
	IF(EXISTS(A(x=I,y=J)), A(x<=I,y<=J), A(x<=I,y<=J)+DATASET([{I,J,0}], Types.Element));