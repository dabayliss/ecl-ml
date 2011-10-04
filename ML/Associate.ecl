IMPORT Types FROM $;

EXPORT Associate(DATASET(Types.ItemElement) d,Types.t_Count M) := MODULE
// This module perform frequent pattern mining
// The concept is that a stream of examples exist; where each example is some number of items gathered together
// The task is to discover which items co-occur and least M times

// The math is trivial - the task is managing the combinatoric size of the intermediate result
// Given the performance critical nature - this module defines its own format; users should use a transform to
// project into the format (this will usually be trivial)


// For the short and swift tasks the Apriori method avoids much complexity - and thus produces speed!
EXPORT Apriori1 := FUNCTION
	R := RECORD
	  d.value;
		Types.t_Count support := COUNT(GROUP);
	END;
	RETURN TABLE(d,r,value,MERGE)(support>=M);
  END;

// Note - the Apriori2 algorithm is not pure - it does not generate candidates and check - rather it generates all the
// checks and reverse engineers the candidates!	
EXPORT Apriori2 := FUNCTION
  // For a pair to appear M times the elements inside have to appear that many times
	// If the candidate list is small enough then use a lookup join to avoid moving the bigger document dataset
	dbl := JOIN(d,Apriori1,LEFT.value=RIGHT.value,TRANSFORM(LEFT));
	dsl := JOIN(d,Apriori1,LEFT.value=RIGHT.value,TRANSFORM(LEFT),LOOKUP);
	dthin := IF ( COUNT(Apriori1) < 10000000, dsl, dbl );
	R := RECORD
	  Types.t_Item value_1;
		Types.t_Item value_2;
		Types.t_Count support := 1;
  END;
	R Take2(dthin le, dthin ri) := TRANSFORM
	  SELF.value_1 := le.value;
		SELF.value_2 := ri.value;
	END;
	J := JOIN(dthin,dthin,LEFT.id = RIGHT.id AND LEFT.value > RIGHT.value,Take2(LEFT,RIGHT));
	R2 := RECORD
	  J.value_1;
		J.value_2;
		Types.t_Count support := SUM(GROUP,J.support);
	END;
	RETURN TABLE(J,R2,value_1,value_2,MERGE)(Support>=M);
END;

// Apriori3 works a little differently - it uses the observation that for a sequence A,B,C to be a 3 pattern with threshold M
// then at the very least A-B, B-C and A-C have to be 2 patterns with threshold M
EXPORT Apriori3 := FUNCTION
	A := Apriori2;
  R := RECORD
	  Types.t_Item value_1;
	  Types.t_Item value_2;
	  Types.t_Item value_3;
	END;
	R Note(A le, A ri) := TRANSFORM
		SELF.value_1 := le.value_1;
		SELF.value_2 := le.value_2;
		SELF.value_3 := ri.value_2;
	END;
// To avoid dups we will only consider ascending sequences
  // First find all pairs with A-B and B-C
	J := JOIN(A,A,LEFT.value_2 = RIGHT.value_1,Note(LEFT,RIGHT));
	// Now make sure A-C exists
	Cands := JOIN(J,A,LEFT.value_1 = RIGHT.value_1 AND LEFT.value_3 = RIGHT.value_2,TRANSFORM(LEFT));

	R1 := RECORD
	  Cands;
		Types.t_RecordId id;
  END;

	R1 WithValue1(D ri,Cands le) := TRANSFORM
		SELF := le;
		SELF := ri;
	END;
  // Generate a record ID / candidate list tuple for every matching record
	With1l := JOIN(D,Cands,LEFT.value = RIGHT.value_1,WithValue1(LEFT,RIGHT));
	With1s := JOIN(D,Cands,LEFT.value = RIGHT.value_1,WithValue1(LEFT,RIGHT),LOOKUP);
	With1 := IF ( COUNT(Cands) > 10000000, With1l, With1s );
	With2l := JOIN(D,With1,LEFT.value = RIGHT.value_2 AND LEFT.id = RIGHT.id,TRANSFORM(RIGHT));
	With2s := JOIN(D,With1,LEFT.value = RIGHT.value_2 AND LEFT.id = RIGHT.id,TRANSFORM(RIGHT),LOOKUP);
	With2 := IF( COUNT(With1) > 1000000, With2l, With2s );
	With3l := JOIN(D,With2,LEFT.value = RIGHT.value_3 AND LEFT.id = RIGHT.id,TRANSFORM(RIGHT));
	With3s := JOIN(D,With2,LEFT.value = RIGHT.value_3 AND LEFT.id = RIGHT.id,TRANSFORM(RIGHT),LOOKUP);
	With3 := IF( COUNT(With2) > 1000000, With3l, With3s );

  Ragg := RECORD
	  With3.value_1;
	  With3.value_2;
	  With3.value_3;
		Types.t_count support := COUNT(GROUP);
  END;
	RETURN TABLE(With3,Ragg,value_1,value_2,value_3,MERGE)(support>=M);
	END;
	
END;