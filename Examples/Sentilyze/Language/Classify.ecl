/**********************************************
* SENTILYZE: LANGUAGE CLASSIFIER - CLASSIFY
* DESCRIPTION: takes a Raw record set and
* outputs a Raw record set of all tweets
* with specified Language Group
* (N = -1 or 1)
***********************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT ML;

EXPORT Classify(DATASET(ML.Docs.Types.Raw) T, INTEGER1 N=1) := FUNCTION

	rLangId := RECORD
		UNSIGNED id;
		INTEGER1 Language;
	END;

	rShortRank := RECORD
		STRING Word;
		UNSIGNED InternalRank;
		UNSIGNED OverallRank;
		INTEGER1 Language;
	END;

	rOverRank := RECORD
		STRING Word;
		INTEGER1 Language;
		UNSIGNED InternalRank;
		REAL InternalFreq;
		UNSIGNED OverallRank;
		REAL OverallFreq;
	END;

	rShortRank GetLanguage(ML.Docs.Types.WordElement L,rOverRank R) := TRANSFORM
		SELF.Word := L.Word;
		SELF.InternalRank := R.InternalRank;
		SELF.OverallRank := R.OverallRank;
		SELF.Language := R.Language;
	END;

	rShortRank SetLanguage(rShortRank R1,rShortRank R2) := TRANSFORM
		SELF.Word := R1.Word;
		SELF.InternalRank := 0;
		SELF.OverallRank := 0;
		SELF.Language := MAP(R1.OverallRank < R2.OverallRank => R1.Language,
				     R1.OverallRank = R2.OverallRank =>IF(R1.InternalRank < R2.InternalRank,R1.Language,R2.Language),R2.Language);
	END;

	rLangId JoinTags(ML.Docs.Types.WordElement L, rShortRank R) := TRANSFORM
		SELF.Id := L.id;
		SELF.Language := R.language;
	END;

	Sentilyze.Types.LanguageType Tag(ML.Docs.Types.Raw L, rLangId R) := TRANSFORM
		SELF.Id := L.Id;
		SELF.Tweet := L.Txt;
		SELF.language := IF(R.language > 0,1,-1);
	END;

	dTokens := ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(T));
	dDedup := DEDUP(dTokens,LEFT.word = RIGHT.word,ALL);
	dGetTags := JOIN(dDedup,Sentilyze.Language.Trainer,LEFT.Word = RIGHT.Word,GetLanguage(LEFT,RIGHT));
	dRollup := ROLLUP(SORT(dGetTags,Word),LEFT.Word = RIGHT.Word,SetLanguage(LEFT,RIGHT));
	dTagTokens := JOIN(dTokens,dGetTags,LEFT.word = RIGHT.word,JoinTags(LEFT,RIGHT));
	rRollupTags := {dTagTokens.id,INTEGER1 language := SUM(GROUP,dTagTokens.language)};
	dRollupTags := TABLE(dTagTokens,rRollupTags,id,MERGE);
	dTagged := JOIN(T,dRollupTags,LEFT.Id = RIGHT.Id,Tag(LEFT,RIGHT));
	dReturn := PROJECT(dTagged(Language=N),TRANSFORM(ML.Docs.Types.Raw,SELF.txt := LEFT.tweet;SELF := LEFT));

	RETURN dReturn;
END;