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

// FILE STRING DEFINITIONS
sPosiTrainer := '~SENTILYZE::TRAINER::POSITIVE'; //Logical File Name of Positive Tweets
sNegaTrainer := '~SENTILYZE::TRAINER::NEGATIVE'; //Logical File Name of Negative Tweets
sModelPersist := '~SENTILYZE::PERSIST::TRAINER::MODEL'; //Logical File Name of Classifier Model
sVocabPersist := '~SENTILYZE::PERSIST::TRAINER::VOCABULARY'; //Logical File Name of Classifier Vocabulary

//Pre-Process Training Data
dPosiTrainer := DATASET(sPosiTrainer,Sentilyze.Types.TweetType,CSV);
dPosiRaw := Sentilyze.PreProcess.ToRaw(dPosiTrainer);
dPosiProcess := Sentilyze.PreProcess.ForTraining(dPosiRaw);
dPosiLanguage := Sentilyze.Language.Classify(dPosiProcess);
dPosiTagged := PROJECT(dPosiLanguage,TRANSFORM(Sentilyze.Types.SentimentType,SELF.id := LEFT.id;SELF.tweet := LEFT.txt;SELF.sentiment := 1));

dNegaTrainer := DATASET(sNegaTrainer,Sentilyze.Types.TweetType,CSV);
dNegaRaw := Sentilyze.PreProcess.ToRaw(dNegaTrainer);
dNegaProcess := Sentilyze.PreProcess.ForTraining(dNegaRaw);
dNegaLanguage := Sentilyze.Language.Classify(dNegaProcess);
dNegaTagged := PROJECT(dNegaLanguage,TRANSFORM(Sentilyze.Types.SentimentType,SELF.id := LEFT.id;SELF.tweet := LEFT.txt;SELF.sentiment := -1));

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
nfDep := DEDUP(JOIN(nfIndep,SentiMerge,LEFT.id = RIGHT.id,ToDep(RIGHT)),LEFT.id = RIGHT.id);
dfDep := ML.Discretize.ByRounding(nfDep);
SentiModel := ML.Classify.NaiveBayes.LearnD(dfIndep,dfDep);

EXPORT Model := MODULE
	EXPORT Vocab := Senticon:PERSIST(sVocabPersist);
	EXPORT Model := SentiModel:PERSIST(sModelPersist);
END;