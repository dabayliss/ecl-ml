/*****************************************************
* SENTILYZE - TWITTER SENTIMENT CLASSIFICATION
* NAIVE BAYES CLASSIFIER - Model
* DESCRIPTION: Creates a model for the ECL-ML 
* Naive Bayes classifier from two datasets of 
* positive and negative tagged tweets. 
******************************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT ML;

ML.Types.NumericField IntoMatrix(ML.Docs.Types.OWordElement L) := TRANSFORM
	SELF.id := L.id;
	SELF.number := L.word;
	SELF.value := L.words_in_doc;
END;

dPosiTrainer := DATASET('~SENTILYZE::TRAINER::POSITIVE',Sentilyze.Types.TweetType,CSV);
dNegaTrainer := DATASET('~SENTILYZE::TRAINER::NEGATIVE',Sentilyze.Types.TweetType,CSV);
dStopwords := DATASET('~SENTILYZE::TRAINER::STOPWORDS',Sentilyze.Types.WordType,CSV);
dPosiEnglish := Sentilyze.Language.Classify(dPosiTrainer,1);
dNegaEnglish := Sentilyze.Language.Classify(dNegaTrainer,1);
dPosiRaw := Sentilyze.PreProcess.ToRaw(Sentilyze.PreProcess.ForTraining(dPosiEnglish));
dNegaRaw := Sentilyze.PreProcess.ToRaw(Sentilyze.PreProcess.ForTraining(dNegaEnglish));
nPosiCount := COUNT(dPosiRaw);
SentiMerge := PROJECT((dPosiRaw + dNegaRaw),TRANSFORM(ML.Docs.Types.Raw,SELF.id := COUNTER, SELF.txt := LEFT.txt));
SentiWords := ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(SentiMerge));
SentiStop := JOIN(SentiWords,dStopwords,LEFT.word = RIGHT.word,TRANSFORM(LEFT),LEFT ONLY);

// Vocabulary
Senticon := ML.Docs.Tokenize.Lexicon(SentiStop);

// Wordbag	
SentiO1 := ML.Docs.Tokenize.ToO(SentiStop,Senticon);
SentiBag := SORT(ML.Docs.Trans(SentiO1).WordBag,id,word);

// Independent and dependent datasets
independents := PROJECT(SentiBag,IntoMatrix(LEFT));
ML.ToField(PROJECT(SentiMerge, TRANSFORM({unsigned id , unsigned value}, SELF.id := LEFT.id, SELF.value := IF(LEFT.id > nPosiCount,0,1))),dependents,id,'value'); // 1 for positive, 0 for negative
independentD := ML.Discretize.ByRounding(independents);
dependentD := ML.Discretize.ByRounding(dependents);

// Train Classifier
Bayes := ML.Classify.NaiveBayes;
SentiModel := Bayes.LearnD(independentD,dependentD);

EXPORT Model := MODULE
	EXPORT Vocab := Senticon:PERSIST('~SENTILYZE::PERSIST::TRAINER::VOCABULARY');
	EXPORT Model := SentiModel:PERSIST('~SENTILYZE::PERSIST::TRAINER::MODEL');
END;