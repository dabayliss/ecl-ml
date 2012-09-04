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

	rClassify := RECORD
		UNSIGNED id;
		UNSIGNED word;
		UNSIGNED words_in_doc;
	END;

	rClassify ToClassify(ML.Docs.Types.OWordElement L) := TRANSFORM
		SELF.words_in_doc := L.words_in_doc;
		SELF := L;
	END;

	Sentilyze.Types.SentimentType TagWithPolarity(ML.Docs.Types.Raw L, INTEGER1 P)	:= TRANSFORM
		SELF.id	:= L.id;
		SELF.Tweet := L.txt;
		SELF.Sentiment := P;
	END;

	//Pre-Process Tweets
	dProcess := Sentilyze.PreProcess.ForAnalysis(T);
	dLanguage := Sentilyze.Language.Classify(dProcess);
	dTokens	:= ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(dLanguage));

	//Get Vocabulary and Model
	TrainModel := Sentilyze.NaiveBayes.Model.Model; 
	TrainVocab := Sentilyze.NaiveBayes.Model.Vocab; 

	//Create Wordbag with Vocabulary
	TweetO1	:= ML.Docs.Tokenize.ToO(dTokens,TrainVocab);
	TweetBag := SORT(ML.Docs.Trans(TweetO1).WordBag,id,word);
	dClassify := PROJECT(TweetBag,ToClassify(LEFT));
	ML.ToField(dClassify,nfClassify);
	dfClassify := ML.Discretize.ByRounding(nfClassify);

	//Classify Tweets with model
	Result := ML.Classify.NaiveBayes.ClassifyD(dfClassify,TrainModel);
	NegaIds := SET(Result (value in [-1]),id);
	PosiIds := SET(Result (value in [1]),id);
	NegaSet := PROJECT(T(id in NegaIds),TagWithPolarity(LEFT,-1));
	PosiSet := PROJECT(T(id in PosiIds),TagWithPolarity(LEFT,1));
	dSentiment := NegaSet + PosiSet;

	RETURN dSentiment;

END;