/**********************************************
* SENTILYZE: KEYWORD COUNT CLASSIFIER
* KEYWORD GENERATOR
* DESCRIPTION: Generates keywords from a TweetType
* record set containing tweets.
***********************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT ML;

EXPORT Generate(DATASET(Sentilyze.Types.TweetType) T,UNSIGNED nWords=100)	:= MODULE

	dDataset:= T;
	SHARED dProcess	:= Sentilyze.PreProcess.ToRaw(Sentilyze.Language.Classify(dDataset));
	dTokens	:= ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(dProcess));
	dNGrams	:= ML.Docs.CoLocation.AllNGrams(dTokens,,1);
	SHARED	dNStats		:= ML.Docs.CoLocation.NGrams(dNGrams);
	
	EXPORT Keywords_TFIDF := FUNCTION
		r_tfidf	:= RECORD
			STRING ngram;
			REAL tf_idf;
		END;

		r_tfidf	Calc_tfidf(ML.Docs.CoLocation.NGramsLayout L)	:= TRANSFORM
			SELF.ngram := L.ngram;
			SELF.tf_idf := L.pct * L.idf;
		END;
		
		d_tfidf := PROJECT(dNStats,Calc_tfidf(LEFT));	
		RETURN PROJECT(TOPN(d_tfidf,nWords,-tf_idf),TRANSFORM(Sentilyze.Types.WordType,SELF.word := LEFT.ngram));
	END;
	

END;