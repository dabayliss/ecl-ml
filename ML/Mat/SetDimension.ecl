IMPORT Types FROM ML.Mat;
IMPORT Strict FROM ML.Mat;
EXPORT SetDimension(DATASET(Types.Element) A, Types.t_Index I, Types.t_Index J) := IF( Strict,
	IF(EXISTS(A(x=I,y=J)), A(x<=I,y<=J), A(x<=I,y<=J)+DATASET([{I,J,0}], Types.Element)),A);