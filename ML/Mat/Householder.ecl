IMPORT * FROM $;
EXPORT Householder := MODULE

// Householder Reflection
// V = houseV(X, k)
// X is a column vector, k an index < length(X)
// Constructs a matrix H that annihilates entries
// in the product H*X below index k
HouseV(DATASET(Types.VecElement) X, Types.t_Index k) := FUNCTION
	
	xk := X(x=k)[1].value;
	alpha := IF(xk>=0, -Vec.Norm(X), Vec.Norm(X));
	vk := SQRT(0.5*(1-xk/alpha));
	p := - alpha * vk;
  RETURN PROJECT(X, TRANSFORM(Types.VecElement,SELF.value := IF(LEFT.x=k, vk, LEFT.value/(2*p)), SELF :=LEFT));
	
END; 

EXPORT Reflection(DATASET(Types.VecElement) X, Types.t_Index k) := FUNCTION
	hV := HouseV(X(x>=k),k);
	houseVM := Vec.ToCol(hV, 1);
	I := Identity(Has(houseVM).Dimension);
	RETURN Sub(I, Scale(Mul(houseVM,Trans(houseVM)),2));

END;


END;