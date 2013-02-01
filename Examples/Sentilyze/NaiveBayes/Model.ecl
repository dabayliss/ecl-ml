/*****************************************************
* SENTILYZE - TWITTER SENTIMENT CLASSIFICATION
* NAIVE BAYES CLASSIFIER - Model
* DESCRIPTION: Creates a model for the ECL-ML 
* Naive Bayes classifier from two datasets of 
* positive and negative tagged tweets. 
******************************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT ML;

ML.Docs.Types.LexiconElement AddOne(ML.Docs.Types.LexiconElement L) := TRANSFORM
//Increases word_id value by 1
//This is so the number "1" can be used for the dependent sentiment variable
	SELF.word_id := L.word_id + 1;
	SELF := L;
END;

ML.Types.NumericField ToIndep(ML.Docs.Types.OWordElement L) := TRANSFORM
//Takes relevant data from ML.Docs.Trans.Wordsbag
//and converts to numericfield
	SELF.id := L.id;
	SELF.number := L.word;
	//Depending on NB Model value is either words_in_doc (term frequency) or 1 (term presence)
	SELF.value := L.words_in_doc;
END;

ML.Types.NumericField ToDep(Sentilyze.Types.SentimentType L) := TRANSFORM
// to extract document ids and sentiment values to a numericfield
	SELF.id := L.id;
	SELF.number := 1;
	SELF.value := L.sentiment;
END;

//Pre-Process Training Data
dPosiTrainer := DATASET(Sentilyze.Strings.PositiveTweets,Sentilyze.Types.TweetType,CSV);
dPosiRaw := Sentilyze.PreProcess.ConvertToRaw(dPosiTrainer);
dPosiProcess := Sentilyze.PreProcess.RemoveTraining(dPosiRaw);
//dPosiProcess := Sentilyze.PreProcess.ReplaceTraining(dPosiRaw);
dPosiTagged := PROJECT(dPosiProcess,TRANSFORM(Sentilyze.Types.SentimentType,SELF.id := LEFT.id;SELF.tweet := LEFT.txt;SELF.sentiment := 1));

dNegaTrainer := DATASET(Sentilyze.Strings.NegativeTweets,Sentilyze.Types.TweetType,CSV);
dNegaRaw := Sentilyze.PreProcess.ConvertToRaw(dNegaTrainer);
dNegaProcess := Sentilyze.PreProcess.RemoveTraining(dNegaRaw);
//dNegaProcess := Sentilyze.PreProcess.ReplaceTraining(dNegaRaw);
dNegaTagged := PROJECT(dNegaProcess,TRANSFORM(Sentilyze.Types.SentimentType,SELF.id := LEFT.id;SELF.tweet := LEFT.txt;SELF.sentiment := -1));

SentiMerge := PROJECT((dPosiTagged + dNegaTagged),TRANSFORM(Sentilyze.Types.SentimentType, SELF.id := COUNTER;SELF := LEFT));
SentiRaw := PROJECT(SentiMerge,TRANSFORM(ML.Docs.Types.Raw,SELF.id := LEFT.id;SELF.txt := LEFT.tweet));
SentiWords := ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(SentiRaw));

//Create Vocabulary
Senticon := PROJECT(ML.Docs.Tokenize.Lexicon(SentiWords),AddOne(LEFT));

//Create Wordbags
SentiO1 := ML.Docs.Tokenize.ToO(SentiWords,Senticon);
SentiBag := SORT(ML.Docs.Trans(SentiO1).WordBag,id,word);

//Train Classifier
nfIndep := PROJECT(SentiBag,ToIndep(LEFT));
dfIndep := ML.Discretize.ByRounding(nfIndep);
nfDep := PROJECT(SentiMerge,ToDep(LEFT));
dfDep := ML.Discretize.ByRounding(nfDep);
SentiModel := ML.Classify.NaiveBayes.LearnD(dfIndep,dfDep);

EXPORT Model := MODULE
	EXPORT Vocab := Senticon:PERSIST(Sentilyze.Strings.BayesVocab);
	EXPORT Model := SentiModel:PERSIST(Sentilyze.Strings.BayesModel);
END;