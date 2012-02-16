IMPORT * FROM $;
EXPORT Householder(DATASET(Types.VecElement) X, Types.t_Index k, Types.t_Index Dim=1) := MODULE

	/* 
		HTA - Householder Transformation Algorithm
			Computes the Householder reflection matrix for use with QR decomposition

			Input:  vector X, k an index < length(X)
			Output: a matrix H that annihilates entries in the product H*X below index k
	*/
  EXPORT HTA := MODULE
	   EXPORT Default := MODULE,VIRTUAL
		  EXPORT IdentityM := IF(Dim>Vec.Length(X), Identity(Dim), Identity(Vec.Length(X)));
			EXPORT DATASET(Types.Element) hReflection := DATASET([],Types.Element);
			
		 END;
		 
		  // Householder Vector
			HouseV(DATASET(Types.VecElement) X, Types.t_Index k) := FUNCTION
				xk := X(x=k)[1].value;
				alpha := IF(xk>=0, -Vec.Norm(X), Vec.Norm(X));
				vk := IF (alpha=0, 1, SQRT(0.5*(1-xk/alpha)));
				p := - alpha * vk;
				RETURN PROJECT(X, TRANSFORM(Types.VecElement,SELF.value := IF(LEFT.x=k, vk, LEFT.value/(2*p)), SELF :=LEFT));
			END; 
			
		 // Source: Atkinson, Section 9.3, p. 611	
		 EXPORT Atkinson := MODULE(Default)
				hV := HouseV(X(x>=k),k);
				houseVec := Vec.ToCol(hV, 1);
				EXPORT DATASET(Types.Element) hReflection := Sub(IdentityM, Scale(Mul(houseVec,Trans(houseVec)),2));
		 END;
		 
		 // Source: Golub and Van Loan, "Matrix Computations" p. 210
		 EXPORT Golub := MODULE(Default)
				VkValue := X(x=k)[1].value;
				VkPlus := X(x>k);
				sigma := Vec.Dot(VkPlus, VkPlus);
	
				mu := SQRT(VkValue*VkValue + sigma);
				newVkValue := IF(sigma=0,1,IF(VkValue<=0, VkValue-mu, -sigma/(VkValue+mu) ));
				beta := IF( sigma=0, 0, 2*(newVkValue*newVkValue)/(sigma + (newVkValue*newVkValue)));
				
				newVkElem0 := X[1];
				newVkElem := PROJECT(newVkElem0,TRANSFORM(Types.Element,SELF.x:=k,SELF.y:=1,SELF.value := newVkValue));

				hV := PROJECT(newVkElem + VkPlus,TRANSFORM(Types.Element,SELF.value:=LEFT.value/newVkValue, SELF := LEFT));
				EXPORT DATASET(Types.Element) hReflection := Sub(IdentityM, Scale(Mul(hV,Trans(hV)),Beta));
		 END;
	
	END;

	EXPORT Reflection(HTA.Default Control = HTA.Golub) := FUNCTION
		RETURN Control.hReflection;
	END;

END;