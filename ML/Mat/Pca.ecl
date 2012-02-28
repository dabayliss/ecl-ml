IMPORT * FROM $;

/*
	http://en.wikipedia.org/wiki/Principal_component_analysis
	Principal component analysis (PCA) is a mathematical procedure that uses an 
	orthogonal transformation to convert a set of observations of possibly 
	correlated variables into a set of values of linearly uncorrelated variables 
	called principal components. The number of principal components is less than 
	or equal to the number of original variables. This transformation is defined 
	in such a way that the first principal component has the largest possible 
	variance (that is, accounts for as much of the variability in the data as 
	possible), and each succeeding component in turn has the highest variance 
	possible under the constraint that it be orthogonal to (i.e., uncorrelated 
	with) the preceding components.

	PCA can be done by eigenvalue decomposition of a data covariance 
	(or correlation) matrix or singular value decomposition of a data matrix, 
	usually after mean centering (and normalizing or using Z-scores) the 
	data matrix for each attribute. The results of a PCA are usually discussed 
	in terms of component scores, sometimes called factor scores (the 
	transformed variable values corresponding to a particular data point), 
	and loadings (the weight by which each standardized original variable 
	should be multiplied to get the component score)

  This PCA solution subtructs the mean value from the matrix (as required). 
	This mean-zeroing of feature vectors converts sparse matrix into a 
	non-sparse matrix, and consequently makes this PCA implementation 
	suitable for relatively small model. 

	To turn this PCA implementation into a scalable solution, look into 
	modifying SVD to deal with the mean-subtruction for PCA implicitely!
*/
EXPORT Pca(DATASET(Types.Element) A, UNSIGNED comp_cnt=0) := MODULE

	CovA := Cov(A);
	U := Svd(CovA).UComp;
	// Ureduce - orthogonal vectors representing new space
	EXPORT Ureduce := IF(comp_cnt=0, U, U(y<=comp_cnt));
	ZeroMeanA := Sub(A, Repmat(Has(A).MeanCol, Has(A).Stats.XMax, 1));
	// ZComp - original features projected to the Ureduce space
	EXPORT ZComp := Trans(Mul(Trans(Ureduce),Trans(ZeroMeanA)));

END;