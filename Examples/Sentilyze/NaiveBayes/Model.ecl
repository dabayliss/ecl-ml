/*****************************************************
* SENTILYZE - TWITTER SENTIMENT CLASSIFICATION
* NAIVE BAYES CLASSIFIER - Model
* DESCRIPTION: Creates a model for the ECL-ML 
* Naive Bayes classifier from two datasets of 
* positive and negative tagged tweets. 
******************************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT ML;

rTrainer := RECORD
	UNSIGNED id;
	UNSIGNED word;
	UNSIGNED1 words_in_doc;
	INTEGER1 sentiment;
END;

rTrainer ToTrainer(ML.Docs.Types.OWordElement L,Sentilyze.Types.SentimentType R) := TRANSFORM
	SELF.words_in_doc := L.words_in_doc;
	SELF.sentiment := R.sentiment;
	SELF := L;
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
Senticon := ML.Docs.Tokenize.Lexicon(SentiWords);

//Create Wordbags
SentiO1 := ML.Docs.Tokenize.ToO(SentiWords,Senticon);
SentiBag := SORT(ML.Docs.Trans(SentiO1).WordBag,id,word);
dTrainer := JOIN(Sentibag,SentiMerge,LEFT.id = RIGHT.id,ToTrainer(LEFT,RIGHT));

//Train Classifier
ML.ToField(dTrainer,nfTrainer);
dfTrainer := ML.Discretize.ByRounding(nfTrainer);
dIndependent := dfTrainer(number < 3);
dDependent := dfTrainer(number = 3);
Bayes := ML.Classify.NaiveBayes;
SentiModel := Bayes.LearnD(dIndependent,dDependent);

EXPORT Model := MODULE
	EXPORT Vocab := Senticon:PERSIST(sVocabPersist);
	EXPORT Model := SentiModel:PERSIST(sModelPersist);
END;