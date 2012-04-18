IMPORT * FROM ML.Mat;
IMPORT Config FROM ML;

MulMethod := ENUM ( Default = 1, SymmetricResult  = 2 );
Mul_Default(DATASET(Types.Element) l,DATASET(Types.Element) r) := FUNCTION

	Types.Element Mu(l le,r ri) := TRANSFORM
		SELF.x := le.x;
		SELF.y := ri.y;
		SELF.value := le.value * ri.value;
	END;
	
  J := JOIN(l,r,LEFT.y=RIGHT.x,Mu(LEFT,RIGHT)); // Form all of the intermediate computations
	
	Inter := RECORD
		J.x;
		J.y;
		Types.t_value value := SUM(GROUP,J.value);
	END;
	
	// Combine all the parts back into a matrix - note if your matrices fit in memory on 1 node - FEW will help
	T := IF(	Has(l).Stats.XMax*Has(r).Stats.YMax*sizeof(Types.Element)>Config.MaxLookup, 
				TABLE(J,Inter,x,y,MERGE), 
				TABLE(J,Inter,x,y,FEW));

	RETURN PROJECT( T , TRANSFORM( Types.Element, SELF := LEFT ) ); // Cast back into matrix type

END;

Mul_SymmetricResult(DATASET(Types.Element) l,DATASET(Types.Element) r) := FUNCTION

	Types.Element Mu(l le,r ri) := TRANSFORM
		SELF.x := le.x;
		SELF.y := ri.y;
		SELF.value := le.value * ri.value;
	END;
	
	// Form all of the intermediate computations below diagonal
  J := JOIN(l,r,LEFT.y=RIGHT.x AND LEFT.x>=RIGHT.y,Mu(LEFT,RIGHT)); 
	
	Inter := RECORD
		J.x;
		J.y;
		Types.t_value value := SUM(GROUP,J.value);
	END;
	
	// Combine all the parts back into a matrix - note if your matrices fit in memory on 1 node - FEW will help
	T := IF(	Has(l).Stats.XMax*Has(r).Stats.YMax*sizeof(Types.Element)>Config.MaxLookup, 
				TABLE(J,Inter,x,y,MERGE), 
				TABLE(J,Inter,x,y,FEW));
				
	mT := PROJECT( T , TRANSFORM( Types.Element, SELF := LEFT ) ); // Cast back into matrix type
		
	// reflect the matrix	
	Types.Element ReflectM(Types.Element le, UNSIGNED c) := TRANSFORM, SKIP (c=2 AND le.x=le.y)
		SELF.x := IF(c=1,le.x,le.y);
		SELF.y := IF(c=1,le.y,le.x);
		SELF := le;
	END;
	
	RETURN NORMALIZE(mT,2,ReflectM(LEFT,COUNTER)); 
	
END;

EXPORT Mul(DATASET(Types.Element) l,DATASET(Types.Element) r, MulMethod method=MulMethod.Default) := FUNCTION
		StatsL := Has(l).Stats;
		StatsR := Has(r).Stats;
		SizeMatch := ~Strict OR (StatsL.YMax=StatsR.XMax);
		
		assertCondition := ~(Debug AND ~SizeMatch);	
		checkAssert := ASSERT(assertCondition, 'Mul FAILED - Size mismatch', FAIL);		
		result := IF(SizeMatch, IF(method=MulMethod.Default, Mul_Default(l,r), Mul_SymmetricResult(l,r)),DATASET([], Types.Element));
		RETURN WHEN(result, checkAssert);
END;		