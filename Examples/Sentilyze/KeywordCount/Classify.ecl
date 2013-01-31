/**********************************************
* SENTILYZE: KEYWORD COUNT CLASSIFIER - CLASSIFY
* DESCRIPTION: Takes a Raw record set
* containing tweets and outputs a SentimentType
* record set with tweets tagged with a positive
* or negative sentiment. 
* (-1 = Negative, 1 = Positive)
***********************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT ML;

EXPORT Classify(DATASET(ML.Docs.Types.Raw) T)	:= FUNCTION

	rSentimentId := RECORD
		UNSIGNED Id;
		INTEGER1 Sentiment;
	END;

	rSentimentId IdSentiment(ML.Docs.Types.WordElement L,INTEGER1 P) := TRANSFORM
		SELF.Id	:= L.id;
		SELF.Sentiment := P;
	END;

	Sentilyze.Types.SentimentType	Sentiment(ML.Docs.Types.Raw L, rSentimentId R) := TRANSFORM
		SELF.Id := L.Id;
		SELF.Tweet := L.Txt;
		SELF.Sentiment := MAP(R.Sentiment > 0 => 1, R.Sentiment < 0 => -1,0);
	END;

	dNegative := DATASET(Sentilyze.Strings.NegativeKeywords,Sentilyze.Types.WordType,CSV);
	dPositive := DATASET(Sentilyze.Strings.PositiveKeywords,Sentilyze.Types.WordType,CSV);
	dTokens := ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(T));
	dNegaTokens := JOIN(dTokens,dNegative,LEFT.Word = RIGHT.Word,IdSentiment(LEFT,-1),LOOKUP);
	dPosiTokens := JOIN(dTokens,dPositive,LEFT.Word = RIGHT.Word,IdSentiment(LEFT,1),LOOKUP);
	dSentiMerge := dNegaTokens + dPosiTokens;
	rRollup := {dSentiMerge.id,INTEGER1 sentiment := SUM(GROUP,dSentiMerge.sentiment)};
	dRollup := TABLE(dSentiMerge,rRollup,id,MERGE);
	dSentiment := JOIN(T,dRollup,LEFT.Id = RIGHT.Id,Sentiment(LEFT,RIGHT));

	RETURN dSentiment(Sentiment!=0);
END;