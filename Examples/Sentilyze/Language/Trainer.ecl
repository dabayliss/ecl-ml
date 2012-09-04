/**********************************************
* SENTILYZE: LANGUAGE CLASSIFIER TRAINER
* DESCRIPTION: creates a record set of
* rank-ordered unigrams categorized by language
* (-1 = Discard, 1 = Keep)
***********************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT ML;

rIntRank := RECORD
	STRING Word;
	UNSIGNED WordCount;
	INTEGER1 Language; //-1 is language to discard, 1 is language to keep
	UNSIGNED InternalRank;
	REAL InternalFreq;
END;

rOverRank := RECORD
	STRING Word;
	INTEGER1 Language;
	UNSIGNED InternalRank;
	REAL InternalFreq;
	UNSIGNED OverallRank;
	REAL OverallFreq;
END;

/*
Assigns Sorted NGram Dataset a Rank Number, 1 being the most frequent
Normalizes frequency values by dividing freq by highest frequency of
dataset and adding 1. (H/T to Ahmed et al. at Pace University)
*/

rIntRank InternalRank(ML.Docs.Types.LexiconElement L,REAL MaxTotal, UNSIGNED1 Language, UNSIGNED C)	:= TRANSFORM
	SELF.word := L.word;
	SELF.WordCount := L.total_words;
	SELF.Language := Language;
	SELF.InternalRank := C;
	SELF.InternalFreq := (L.total_words/MaxTotal) + 1;
END;

rIntRank NormInternalRank(rIntRank L, rIntRank R, UNSIGNED C)	:= TRANSFORM
	SELF.InternalRank := IF(L.InternalFreq = R.InternalFreq,L.InternalRank,C);
	SELF := R;
END;

rOverRank OverallFreq(rIntRank L, UNSIGNED MaxTotal, UNSIGNED C)	:= TRANSFORM
	SELF.OverallRank := C;
	SELF.OverallFreq := (L.WordCount/MaxTotal) + 1;
	SELF := L;
END;

rOverRank NormOverallRank(rOverRank L, rOverRank R, UNSIGNED C) := TRANSFORM
	SELF.OverallRank := IF(L.OverallFreq = R.OverallFreq,L.OverallRank,C);
	SELF := R;
END;

// FILE STRING DEFINITIONS
sKeep := '~SENTILYZE::TRAINER::KEEP'; //Logical File Name of Tweets of Language to Keep
sDiscard := '~SENTILYZE::TRAINER::DISCARD'; //Logical File Name of Tweets of Language to Discard
sTrainer := '~SENTILYZE::PERSIST::TRAINER::LANGUAGE'; //Logical File Name of Language Classifier Trainer

// DEFINITIONS
dKeep := DATASET(sKeep,Sentilyze.Types.TweetType,CSV);
dKeepRaw := Sentilyze.PreProcess.ToRaw(dKeep);
dKeepProcess := Sentilyze.PreProcess.ForTraining(dKeepRaw);
dKeepTokens := ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(dKeepProcess));
dKeepLexicon := ML.Docs.Tokenize.Lexicon(dKeepTokens);
nKeepMax := MAX(dKeepLexicon,dKeepLexicon.total_words);
dKeepRank := PROJECT(dKeepLexicon,InternalRank(LEFT,nKeepMax,1,COUNTER));
dKeepNorm := ITERATE(dKeepRank,NormInternalRank(LEFT,RIGHT,COUNTER));

dDiscard := DATASET(sDiscard,Sentilyze.Types.TweetType,CSV);
dDiscardRaw := Sentilyze.PreProcess.ToRaw(dDiscard);
dDiscardProcess := Sentilyze.PreProcess.ForTraining(dDiscardRaw);
dDiscardTokens := ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(dDiscardProcess));
dDiscardLexicon := ML.Docs.Tokenize.Lexicon(dDiscardTokens);
nDiscardMax := MAX(dDiscardLexicon,dDiscardLexicon.total_words);
dDiscardRank := PROJECT(dDiscardLexicon,InternalRank(LEFT,nDiscardMax,-1,COUNTER));
dDiscardNorm := ITERATE(dDiscardRank,NormInternalRank(LEFT,RIGHT,COUNTER));


dMerge := dKeepNorm + dDiscardNorm;
nWordMax := MAX(dMerge,dMerge.WordCount);
dMergeFreq := SORT(PROJECT(dMerge,OverallFreq(LEFT,nWordMax,COUNTER)),-overallfreq,-internalfreq);
dRank := ITERATE(dMergeFreq,NormOverallRank(LEFT,RIGHT,COUNTER));

EXPORT Trainer := dRank:PERSIST(sTrainer);