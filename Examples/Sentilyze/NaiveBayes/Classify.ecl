/*****************************************************
* SENTILYZE - TWITTER SENTIMENT CLASSIFICATION
* NAIVE BAYES CLASSIFIER - CLASSIFY
* DESCRIPTION: Takes a Raw dataset and runs it
* through the classifier using the model built in 
* NaiveBayes.Model returning a SentimentType dataset
******************************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT ML;

EXPORT Classify(DATASET(ML.Docs.Types.Raw) T) := FUNCTION

	ML.Types.NumericField ToIndep(ML.Docs.Types.OWordElement L) := TRANSFORM
	//Takes relevant data from ML.Docs.Trans.Wordbag
	//and converts to numericfield
		SELF.id := L.id;
		SELF.number := L.word;
		//Depending on NB Model value is either words_in_doc (term frequency) or 1 (term presence)
		SELF.value := L.words_in_doc;
	END;

	Sentilyze.Types.SentimentType TagWithPolarity(ML.Docs.Types.Raw L, INTEGER1 P)	:= TRANSFORM
		SELF.id	:= L.id;
		SELF.Tweet := L.txt;
		SELF.Sentiment := P;
	END;

	//Pre-Process Tweets
	dTokens	:= ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(T));

	//Get Vocabulary and Model
	TrainModel := Sentilyze.NaiveBayes.Model.Model; 
	TrainVocab := Sentilyze.NaiveBayes.Model.Vocab; 

	//Create Wordbag with Vocabulary
	TweetO1	:= ML.Docs.Tokenize.ToO(dTokens,TrainVocab);
	TweetBag := SORT(ML.Docs.Trans(TweetO1).WordBag,id,word);

	//Classify Tweets with model
	nfIndep := PROJECT(TweetBag,ToIndep(LEFT));
	dfIndep := ML.Discretize.ByRounding(nfIndep);
	Result := ML.Classify.NaiveBayes.ClassifyD(dfIndep,TrainModel);
	NegaIds := SET(Result (value in [-1]),id);
	PosiIds := SET(Result (value in [1]),id);
	NegaSet := PROJECT(T(id in NegaIds),TagWithPolarity(LEFT,-1));
	PosiSet := PROJECT(T(id in PosiIds),TagWithPolarity(LEFT,1));
	dSentiment := NegaSet + PosiSet;

	RETURN dSentiment;

END;