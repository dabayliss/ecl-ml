IMPORT * FROM $;
/*
	http://en.wikipedia.org/wiki/Covariance_matrix

 Covariance matrix (also known as dispersion matrix) is a matrix whose 
 element in the i, j position is the covariance between the ith and jth 
 columns of the original matrix.
*/
EXPORT Cov(DATASET(Types.Element) A) :=  FUNCTION

	ZeroMeanA := Sub(A, Repmat(Has(A).MeanCol, Has(A).Stats.XMax, 1));

	SF := 1/(Has(A).Stats.XMax-1);
	RETURN Scale(Mul(Trans(ZeroMeanA),ZeroMeanA, 2), SF);
END;