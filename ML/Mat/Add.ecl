IMPORT * FROM ML.Mat;
// I suspect some would argue I should common up the Add & Subtract code; or use Scale to map between the two
// These are fundamental low-level operations; and it is less that 10 lines of code
EXPORT Add(DATASET(Types.Element) l,DATASET(Types.Element) r) := FUNCTION
StatsL := Has(l).Stats;
StatsR := Has(r).Stats;
SizeMatch := ~Strict OR (StatsL.XMax=StatsR.XMax AND StatsL.YMax=StatsR.YMax);
// Only slight nastiness is that these matrices may be sparse - so either side could be null
Types.Element Ad(l le,r ri) := TRANSFORM
    SELF.x := IF ( le.x = 0, ri.x, le.x );
    SELF.y := IF ( le.y = 0, ri.y, le.y );
	  SELF.value := le.value + ri.value; // Fortuitously; 0 is the null value
  END;
	
assertCondition := ~(Debug AND ~SizeMatch);	
checkAssert := ASSERT(assertCondition, 'Add FAILED - Size mismatch', FAIL);		
result := IF(SizeMatch, JOIN(l,r,LEFT.x=RIGHT.x AND LEFT.y=RIGHT.y,Ad(LEFT,RIGHT),FULL OUTER), DATASET([], Types.Element));
	RETURN WHEN(result, checkAssert);
END;
