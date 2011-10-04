// This module exists to perform internal transforms upon an OWordElement stream
// Internal means 'only from information already there' - more sophisticated work is done elsewhere
IMPORT Types FROM $;

EXPORT Trans(DATASET(Types.OWordElement) j) := MODULE


// The word-bag representation loses the primary meaning of the position element (although it is retained as 'first')
// The document gains the count of 
EXPORT WordBag := FUNCTION

	R := RECORD
		j.id;
		Types.t_Position pos := MIN(GROUP,j.pos);
		j.word;
		Types.t_Count total_words := MAX(GROUP,j.total_words);
		Types.t_Count total_docs := MAX(GROUP,j.total_docs);
		Types.t_Count words_in_doc := COUNT(GROUP);
	END;
	RETURN PROJECT( TABLE(J,R,id,word,MERGE), TRANSFORM(Types.OWordElement,SELF := LEFT));

END;
	
EXPORT WordsCounted := FUNCTION
	
	T := WordBag(words_in_doc>1); // Simple device to reduce size of RHS in join (combined with left outer)
	
	Types.OWordElement take_wid(j le, t ri) := TRANSFORM
		SELF.words_in_doc := IF ( ri.words_in_doc <> 0, ri.words_in_doc, 1 );
	  SELF := le;
	END;

	RETURN JOIN(J,T,LEFT.word=RIGHT.word AND LEFT.id=RIGHT.id,take_wid(LEFT,RIGHT),LEFT OUTER);

END;

END;