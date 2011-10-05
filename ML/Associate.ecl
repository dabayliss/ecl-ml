IMPORT * FROM $;
IMPORT Std.Str;

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
	dthin := IF ( COUNT(Apriori1) < Config.MaxLookup/SIZEOF(Apriori1), dsl, dbl );
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
	With1 := JOIN(D,Cands,LEFT.value = RIGHT.value_1,WithValue1(LEFT,RIGHT));
	With2 := JOIN(D,With1,LEFT.value = RIGHT.value_2 AND LEFT.id = RIGHT.id,TRANSFORM(RIGHT));
	With3 := JOIN(D,With2,LEFT.value = RIGHT.value_3 AND LEFT.id = RIGHT.id,TRANSFORM(RIGHT));

  Ragg := RECORD
	  With3.value_1;
	  With3.value_2;
	  With3.value_3;
		Types.t_count support := COUNT(GROUP);
  END;
	RETURN TABLE(With3,Ragg,value_1,value_2,value_3,MERGE)(support>=M);
	END;

// Will find all sets up to and including those of size N
// If MinN is set the the process will only return those of size >= MinN
EXPORT AprioriN(UNSIGNED2 N,UNSIGNED2 MinN=0) := FUNCTION

// Service functions and support pattern
	NotFirst(STRING S) := S[Str.Find(S,' ',1)+1..];
	NotLast(STRING S) := S[1..Str.Find(S,' ',Str.FindCount(S,' '))-1];
	NotNN(STRING S,UNSIGNED2 NN) := S[1..Str.Find(S,' ',NN-1)]+S[Str.Find(S,' ',NN)+1..];

  PatternRec := RECORD
		Types.t_Count Support;
		STRING        Pat;
	END;

// Use the hard-wired Apriori2 and steal the results	
	PatternRec From2(Apriori2 le) := TRANSFORM
	  SELF.Pat := (STRING)le.value_1+' '+(STRING)le.value_2;
	  SELF := le;
	END;

	FA2 := PROJECT(Apriori2,From2(LEFT));
	
	// This function generates the next set of candidates to try to find in the database
	GenCands(DATASET(PatternRec) di) := FUNCTION
			// First general all the possible ones - a new possible candidate will have the tail of one matching the head of the other
			PatternRec JP(di le,di ri) := TRANSFORM
			  SELF.Pat := Str.GetNthWord(le.pat,1)+' '+ri.pat;
			  SELF := le;
			END;
			J := JOIN(di,di,NotFirst(LEFT.pat)=NotLast(RIGHT.pat),JP(LEFT,RIGHT));
			/* Now we want to check that all the other patterns in our candidate pattern (formed by having an item in the middle missing)
				 are also present in our test set 
				 CheckMissing checks all the patterns with element l missing
			*/
			PatternRec CheckMissing(DATASET(PatternRec) i,UNSIGNED2 l) := FUNCTION
			  RETURN JOIN(i,di,NotNN(LEFT.pat,1+l)=RIGHT.pat,TRANSFORM(LEFT));
//			  RETURN JOIN(i,di,NotNN(LEFT.pat,1+l)=RIGHT.pat,TRANSFORM(LEFT));
			END;
			ThisSize := Str.WordCount(J[1].Pat);
			L := LOOP(J,ThisSize-2,CheckMissing(ROWS(LEFT),COUNTER));
			
			RETURN L;
	END;

	// Find out how much support there is for a given candidate set
	ScoreCands(DATASET(PatternRec) Cands) := FUNCTION
		PR2 := RECORD(PatternRec)
			Types.t_RecordId id;
		END;

		PR2 TakeID(D le,Cands ri) := TRANSFORM
			SELF.id := le.id;
			SELF := ri;
		END;
		CandSize := MAX(Cands,LENGTH(TRIM(Pat)))+8;
  // Generate a record ID / candidate list tuple for every matching record
		With1 := JOIN(D,Cands,LEFT.value = (UNSIGNED)Str.GetNthWord(RIGHT.pat,1),TakeID(LEFT,RIGHT));
		ThisSize := Str.WordCount(Cands[1].Pat);
		// Now step through only keeping doc-ids that match all the items
		PR2 LoopBody(DATASET(PR2) le,UNSIGNED2 NN) := FUNCTION
				RETURN JOIN(D,le,LEFT.value = (UNSIGNED)Str.GetNthWord(RIGHT.pat,NN) AND LEFT.id = RIGHT.id,TRANSFORM(RIGHT));
		END;
		L := LOOP( With1, ThisSize-1, LoopBody(ROWS(LEFT),COUNTER+1) );
		RS := RECORD
		  L.Pat;
			Types.t_Count Support := COUNT(GROUP);
		END;
		RETURN PROJECT( TABLE(L,RS,Pat)(Support>=M), TRANSFORM(PatternRec, SELF := LEFT));
	END;
	
	// Assuming Candidates exist for levels 2 -> NN-1, generate candidates for level N
	GenerateLevel(DATASET(PatternRec) Cands,UNSIGNED2 NN) := FUNCTION
	// Only need candidate groups at level NN-1
		Needed := Cands(Str.WordCount(Pat)=NN-1);
		PassThru := Cands(Str.WordCount(Pat)>=MinN); // No need to pass through the minnows
	// Generate next level (NN)
		Possibles := GenCands(Needed);
	// Score them
		Actuals := ScoreCands(Possibles);
	// Pass through if nothing generated at last level
		RETURN IF ( EXISTS(Needed),PassThru+Actuals,PassThru );
	END;
	
	Res := LOOP(FA2,N-2,GenerateLevel(ROWS(LEFT),COUNTER+2))(Str.WordCount(Pat)>=MinN);
	
	RETURN IF ( N = 2, FA2, Res );
	
  END;
	
END;