/**********************************************
* SENTILYZE: LANGUAGE CLASSIFIER - CLASSIFY
* DESCRIPTION: takes a TweetType record set and
* outputs a LanguageType record set of all tweets
* with specified Language 
* (-1 = Non-English, 1 = English)
***********************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT ML;

EXPORT Classify(DATASET(Sentilyze.Types.TweetType) T, INTEGER1 N=1) := FUNCTION		

	LanguageType := Sentilyze.Types.LanguageType;
	TokenType := ML.Docs.Types.WordElement;

	rShortRank := RECORD
		STRING NGram;
		UNSIGNED InternalRank;
		UNSIGNED OverallRank;
		UNSIGNED1 Language;
	END;

	rOverRank := RECORD
		STRING NGram;
		UNSIGNED NGramCount;
		INTEGER1 Language;
		UNSIGNED InternalRank;
		REAL InternalFreq;
		UNSIGNED OverallRank;
		REAL OverallFreq;
	END;

	rShortRank ExtractLanguage(TokenType L,rOverRank R) := TRANSFORM
		SELF.Ngram := L.Word;
		SELF.InternalRank := R.InternalRank;
		SELF.OverallRank := R.OverallRank;
		SELF.Language := R.Language;
	END;

	rShortRank MineLanguage(rShortRank R1,rShortRank R2) := TRANSFORM
		SELF.Ngram := R1.NGram;
		SELF.InternalRank := 0;
		SELF.OverallRank := 0;
		SELF.Language := MAP(R1.OverallRank < R2.OverallRank => R1.Language,
				     R1.OverallRank = R2.OverallRank =>IF(R1.InternalRank < R2.InternalRank,R1.Language,R2.Language),R2.Language);
	END;

	LanguageType MatchTags(ML.Docs.Types.WordElement L, rShortRank R) := TRANSFORM
		SELF.Id := L.id;
		SELF.Tweet := L.word;
		SELF.Language := R.language;
	END;

	LanguageType SumTags(LanguageType L, LanguageType R) := TRANSFORM
		SELF.Id := L.Id;
		SELF.Tweet := L.Tweet;
		SELF.language := L.language + R.language;	
	END;

	LanguageType FinalTag(ML.Docs.Types.Raw L, LanguageType R) := TRANSFORM
		SELF.Id := L.Id;
		SELF.Tweet := L.Txt;
		SELF.language := IF(R.language > 0,1,-1);
	END;

	dProcess := Sentilyze.PreProcess.ToRaw(Sentilyze.PreProcess.ForAnalysis(T));
	dTokens	:= ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(dProcess)); 
	dDedup	:= DEDUP(dTokens,LEFT.word = RIGHT.word,ALL);
	dTagged	:= JOIN(dDedup,Sentilyze.Language.Trainer,LEFT.Word = RIGHT.Ngram,ExtractLanguage(LEFT,RIGHT));
	dRollupNgrams := ROLLUP(SORT(dTagged,NGram),LEFT.Ngram = RIGHT.Ngram,MineLanguage(LEFT,RIGHT));
	dTokenTagged := JOIN(dTokens,dTagged,LEFT.word = RIGHT.ngram,MatchTags(LEFT,RIGHT));
	dRollupTweets := ROLLUP(SORT(dTokenTagged,id),LEFT.id = RIGHT.id,SumTags(LEFT,RIGHT));
	dClassified := JOIN(dProcess,dRollupTweets,LEFT.Id = RIGHT.Id,FinalTag(LEFT,RIGHT));
	dReturn := PROJECT(dClassified(Language=N),TRANSFORM(Sentilyze.Types.TweetType,SELF.tweet := LEFT.tweet));

	RETURN dReturn;
END;