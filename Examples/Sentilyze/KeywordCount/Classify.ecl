/**********************************************
* SENTILYZE: KEYWORD COUNT CLASSIFIER - CLASSIFY
* DESCRIPTION: Takes a TweetType record set 
* containing tweets and outputs a SentimentType
* record set with tweets tagged with a positive
* or negative sentiment. 
* (-1 = Negative, 1 = Positive)
***********************************************/
IMPORT Sentilyze;
IMPORT ML;

EXPORT Classify(DATASET(Sentilyze.Types.TweetType) T)	:= FUNCTION

	rSentimentId	:= RECORD
		UNSIGNED Id;
		INTEGER1 Sentiment;
	END;

	rSentimentId	IdSentiment(ML.Docs.Types.WordElement L,INTEGER1 P)	:= TRANSFORM
		SELF.Id	:= L.id;
		SELF.Sentiment := P;
	END;

	rSentimentId	SumSentiment(rSentimentId R1, rSentimentId R2)	:= TRANSFORM
		SELF.Id	:= R1.Id;
		SELF.Sentiment := R1.Sentiment + R2.Sentiment;
	END;

	Sentilyze.Types.SentimentType	Sentiment(ML.Docs.Types.Raw L, rSentimentId R)	:= TRANSFORM
		SELF.Id	:= L.Id;
		SELF.Tweet := L.Txt;
		SELF.Sentiment := MAP(R.Sentiment > 0 => 1, R.Sentiment < 0 => -1,0);
	END;

	dNegative	:= Sentilyze.KeywordCount.Trainer.Negative;
	dPositive	:= Sentilyze.KeywordCount.Trainer.Positive;
	dTweets		:= Sentilyze.PreProcess.ToRaw(Sentilyze.Language.Classify(T,1));
	dTokens		:= SORT(ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(dTweets)),Word);
	dNegaTokens	:= JOIN(dTokens,dNegative,LEFT.Word = RIGHT.Word,IdSentiment(LEFT,-1),LOOKUP);
	dPosiTokens	:= JOIN(dTokens,dPositive,LEFT.Word = RIGHT.Word,IdSentiment(LEFT,1),LOOKUP);
	dSentiSort	:= SORT(dNegaTokens + dPosiTokens,id);
	dRollup		:= ROLLUP(dSentiSort,LEFT.Id = RIGHT.Id,SumSentiment(LEFT,RIGHT));
	dSentiment	:= JOIN(dTweets,dRollup,LEFT.Id = RIGHT.Id,Sentiment(LEFT,RIGHT));	

	RETURN dSentiment(Sentiment!=0);
END;