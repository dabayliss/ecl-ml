/*****************************************************
* SENTILYZE - TWITTER SENTIMENT CLASSIFICATION
* NAIVE BAYES CLASSIFIER - CLASSIFY
* DESCRIPTION: Takes a dataset of tweets and runs it
* through the classifier using the model built in 
* NaiveBayes.Model
******************************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT ML;

EXPORT Classify(DATASET(Sentilyze.Types.TweetType) T) := FUNCTION

	ML.Types.NumericField IntoMatrix(ML.Docs.Types.OWordElement l) := TRANSFORM
		SELF.id := l.id;
		SELF.number := l.word;
		SELF.value :=  l.words_in_doc;
	END;		

	Sentilyze.Types.SentimentType TagWithPolarity(ML.Docs.Types.Raw L, INTEGER1 P)	:= TRANSFORM
		SELF.id	:= L.id;
		SELF.Tweet := L.txt;
		SELF.Sentiment := P;
	END;

	//Pre-Process Tweets

	Language := Sentilyze.Language;
	dStopwords := DATASET('~SENTILYZE::TRAINER::STOPWORDS',Sentilyze.Types.WordType,CSV);
	dEngTweets := PROJECT(Language.Classify(T,1),TRANSFORM(ML.Docs.Types.Raw,SELF.id := COUNTER,SELF.txt := LEFT.tweet));
	dTokens	:= ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(dEngTweets));
	dStop := JOIN(dTokens,dStopwords,LEFT.word = RIGHT.word,TRANSFORM(LEFT),LEFT ONLY);

	//Create Vocabularies
	TrainModel := Sentilyze.NaiveBayes.Model.Model; 
	TrainVocab := Sentilyze.NaiveBayes.Model.Vocab; 
	IntVocab := ML.Docs.Tokenize.Lexicon(dStop);
	TweetVocab := SORT(JOIN(IntVocab,TrainVocab,LEFT.word = RIGHT.word,TRANSFORM(ML.Docs.Types.LexiconElement, SELF.word_id := left.word_id, SELF := RIGHT)),word_id);

	//Create Wordbag
	TweetO1	:= ML.Docs.Tokenize.ToO(dTokens,TweetVocab);
	TweetBag := SORT(ML.Docs.Trans(TweetO1).WordBag,id,word);

	//Create Independent Variables

	TweetIndep := PROJECT(TweetBag,IntoMatrix(LEFT));
	TweetIndepD := ML.Discretize.ByRounding(TweetIndep);

	//Classify Tweets
	Result := ML.Classify.NaiveBayes.ClassifyD(TweetIndepD,TrainModel);

	NegaIds := SET(Result (value in [0]),id);
	PosiIds := SET(Result (value in [1]),id);
	NegaSet := PROJECT(dEngTweets(id in NegaIds),TagWithPolarity(LEFT,-1));
	PosiSet := PROJECT(dEngTweets(id in PosiIds),TagWithPolarity(LEFT,1));
	SentiSet := NegaSet + PosiSet;

	RETURN SentiSet;
		
END;