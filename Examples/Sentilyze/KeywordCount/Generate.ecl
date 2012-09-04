/**********************************************
* SENTILYZE: KEYWORD COUNT CLASSIFIER
* KEYWORD GENERATOR
* DESCRIPTION: Generates keywords from a Raw dataset
* containing tweets
***********************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT ML;

EXPORT Generate(DATASET(ML.Docs.Types.Raw) T,UNSIGNED nWords=100) := MODULE

	dProcess := Sentilyze.PreProcess.ForTraining(T);
	SHARED dLanguage := Sentilyze.Language.Classify(dProcess);
	SHARED dTokens := ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(dLanguage));
	SHARED dLexicon := ML.Docs.Tokenize.Lexicon(dTokens);

	EXPORT Keywords_TFIDF := FUNCTION
		r_tfidf	:= RECORD
			STRING word;
			REAL tf_idf;
		END;

		dO := ML.Docs.Tokenize.ToO(dTokens,dLexicon);
		d_tfidf := ML.Docs.Trans(dO).Tfidf(0);
		t_tfidf := TABLE(d_tfidf,{d_tfidf.word_id,REAL tf_idf := SUM(GROUP,d_tfidf.tf_idf)},word_id,MERGE);
		dReturn := JOIN(dLexicon,t_tfidf,LEFT.word_id = RIGHT.word_id,TRANSFORM(r_tfidf,SELF.word := LEFT.word;SELF.tf_idf := RIGHT.tf_idf));
		RETURN TOPN(dReturn,nWords,-tf_idf);
	END;
	
	EXPORT Keywords_MI(DATASET(ML.Docs.Types.Raw) O, UNSIGNED nThreshold=0,UNSIGNED units=2) := FUNCTION
		oProcess := Sentilyze.PreProcess.ForTraining(O);
		oLanguage := Sentilyze.Language.Classify(O);
		dMi := ML.Docs.CoLocation.MutualInfo(dLanguage,oLanguage,nThreshold,units);
		RETURN TOPN(dMI,nWords,-mi);
	END;

END;