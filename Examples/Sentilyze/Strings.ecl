/**********************************************
* SENTILYZE: STRINGS MODULE
* DESCRIPTION: contains logical file names of all
* datasets required for Sentilyze.
***********************************************/
EXPORT Strings := MODULE
	
	// KeywordCount Sentiment Classifier
	EXPORT NegativeKeywords := '~SENTILYZE::TRAINER::NEGAWORDS'; //Logical File Name of Negative Keywords
	EXPORT PositiveKeywords := '~SENTILYZE::TRAINER::POSIWORDS'; //Logical File Name of Positive Keywords
	
	// Naive Bayes Sentiment Classifier
	EXPORT PositiveTweets := '~SENTILYZE::TRAINER::POSITWEETS'; //Logical File Name of Positive Tweets
	EXPORT NegativeTweets := '~SENTILYZE::TRAINER::NEGATWEETS'; //Logical File Name of Negative Tweets
	EXPORT BayesModel := '~SENTILYZE::TRAINER::BAYESMODEL'; //Logical File Name of Classifier Model
	EXPORT BayesVocab := '~SENTILYZE::TRAINER::VOCABULARY'; //Logical File Name of Classifier Vocabulary

END;