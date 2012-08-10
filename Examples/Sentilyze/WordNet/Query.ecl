/**************************************************
* SENTILYZE: WORDNET QUERY MODULE
* DESCRIPTION: Contains functions to get a dataset 
* of similar words and to expand an
* existing dataset with similar words
**************************************************/
IMPORT Examples.Sentilyze AS Sentilyze;

EXPORT Query := MODULE
	SHARED	WordNet		:= Sentilyze.WordNet;
	/*
	*		GetSimilar
	*		Input: Dataset of Strings (Words)
	* 	Output: Dataset of Words and their Synonyms
	*/
	EXPORT	GetSimilar(DATASET(Sentilyze.Types.WordType) w)	:= FUNCTION		
		Synset	:= WordNet.Synset;
		
		Synset.Layout	GetWordId(Sentilyze.Types.WordType L,Synset.Layout R)	:= TRANSFORM
			SELF.Word	:= L.Word;
			SELF.SynsetId	:= R.SynsetId;
		END;
		
		WordWithId	:= JOIN(w,Synset.File,LEFT.Word = RIGHT.Word,GetWordId(LEFT,RIGHT));
		
		SimilarIdLayout	:= RECORD
			STRING Word;
			UNSIGNED4 SynsetId1;
			UNSIGNED4 SynsetId2;
		END;

		SimilarIdLayout	GetSimilarId(Synset.Layout word, WordNet.Similar.Layout similar)	:= TRANSFORM
			SELF.Word	:= word.Word;
			SELF.SynsetId1	:= word.SynsetId;
			SELF.SynsetId2	:= similar.SynsetId2;
		END;

		WordWithSimilarId	:= JOIN(WordWithId,WordNet.Similar.File,LEFT.SynsetId = RIGHT.SynsetId1,GetSimilarId(LEFT,RIGHT));
		
		WordWithSimilarLayout	:= RECORD
			STRING Word;
			STRING Similar;
		END;

		WordWithSimilarLayout	GetSimilarWord(SimilarIdLayout L, Synset.Layout R) := TRANSFORM
			SELF.Word	:= L.Word;
			SELF.Similar	:= R.Word;
		END;

		WordWithSimilar := JOIN(WordWithSimilarId,Synset.File,LEFT.SynsetId2 = RIGHT.SynsetId,GetSimilarWord(LEFT,RIGHT));
		
		RETURN	WordWithSimilar;
	
	END;
	/**************************************************
	* ExpandList
	* Input: Dataset of Strings (Words)
	* Output: Dataset of More Words
	***************************************************/
	EXPORT	Expand(DATASET(Sentilyze.Types.WordType) w)	:= FUNCTION
		InitialList	:= w;
		SimilarList	:= GetSimilar(InitialList);
		
		SliceLayout	:= RECORD
			STRING Word	:= SimilarList.Similar;
		END;
		
		SimilarSlice := Table(SimilarList,SliceLayout);
		SimilarAgainList	:= GetSimilar(SimilarSlice);
		
		SimilarResultLayout	:= RECORD
			STRING Word;
			STRING Similar;
		END;

		Sentilyze.Types.WordType	MatchLists(SimilarResultLayout L)	:= TRANSFORM
			SELF.Word	:= L.Word;
		END;
		
		MatchedList	:= JOIN(SimilarAgainList,InitialList,LEFT.Similar = RIGHT.Word,MatchLists(LEFT));
		SortedMatchedList	:= SORT(MatchedList,Word);
		FinalList	:= DEDUP(SortedMatchedList,ALL);
		ExpandedList	:= SORT(InitialList+FinalList,Word);
		
		RETURN ExpandedList;		
	END;
END;