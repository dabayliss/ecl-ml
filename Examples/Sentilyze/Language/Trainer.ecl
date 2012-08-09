/**********************************************
* SENTILYZE: LANGUAGE CLASSIFIER TRAINER
* DESCRIPTION: creates a record set of 
* rank-ordered unigrams categorized by language
* (-1 = Non-English, 1 = English)
***********************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT ML;

rNorm := RECORD
	STRING		NGram;
	UNSIGNED	NGramCount;
	INTEGER1	Language;	//-1 is Non-English, 1 is English
	UNSIGNED	InternalRank;
	REAL		InternalFreq;
END;

rOverFreq := RECORD
	STRING		NGram;
	UNSIGNED	NGramCount;
	INTEGER1	Language;
	UNSIGNED	InternalRank;
	REAL			InternalFreq;
	REAL			OverallFreq;
END;

rOverRank := RECORD
	STRING NGram;
	UNSIGNED NGramCount;
	INTEGER1 Language;
	UNSIGNED InternalRank;
	REAL InternalFreq;
	UNSIGNED OverallRank;
	REAL OverallFreq;
END;

rOverRank RankOverall(rOverFreq L, UNSIGNED C, REAL MaxFreq) := TRANSFORM
	SELF.NGram := L.NGram;
	SELF.NGramCount := L.NGramCount;
	SELF.Language := L.Language;
	SELF.InternalRank := L.InternalRank;
	SELF.InternalFreq := L.InternalFreq;
	SELF.OverallRank := C;
	SELF.OverallFreq := (L.OverallFreq/MaxFreq)+1
END;


/*
Assigns Sorted NGram Dataset a Rank Number, 1 being the most frequent
Normalizes frequency values by dividing freq by highest frequency of
dataset and added 1. (H/T to Pace University)
*/
rNorm NormalizeRank(ML.Docs.CoLocation.NGramsLayout L, UNSIGNED C, REAL MaxFreq, UNSIGNED1 Language)	:= TRANSFORM
	SELF.NGram := L.NGram;
	SELF.NGramCount := L.DocCount;
	SELF.Language := Language;
	SELF.InternalRank := C;
	SELF.InternalFreq := (L.Pct/MaxFreq) + 1;
END;

rOverFreq OverallFreq(rNorm L, UNSIGNED ngramNum)	:= TRANSFORM
	SELF.OverallFreq := L.NGramCount/ngramNum;
	SELF := L;
END;

// DEFINITIONS

dEng := DATASET('~SENTILYZE::TRAINER::ENGLISH',Sentilyze.Types.TweetType,CSV);
dEngProcess := Sentilyze.PreProcess.ToRaw(Sentilyze.PreProcess.ForTraining(dEng));
dEngTokens := ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(dEngProcess));
dEngNGrams := ML.Docs.CoLocation.AllNGrams(dEngTokens);
dEngStats := ML.Docs.CoLocation.NGrams(dEngNGrams);
dEngSort := SORT(dEngStats,-DocCount);
nEngMax := MAX(dEngSort,dEngSort.pct);
dEngNorm := PROJECT(dEngSort,NormalizeRank(LEFT,COUNTER,nEngMax,1));

dNon := DATASET('~SENTILYZE::TRAINER::NONENGLISH',Sentilyze.Types.TweetType,CSV);
dNonProcess := Sentilyze.PreProcess.ToRaw(Sentilyze.PreProcess.ForTraining(dNon));
dNonTokens := ML.Docs.Tokenize.Split(ML.Docs.Tokenize.Clean(dNonProcess));
dNonNGrams := ML.Docs.CoLocation.AllNGrams(dNonTokens);
dNonStats := ML.Docs.CoLocation.NGrams(dNonNGrams);
dNonSort := SORT(dNonStats,-DocCount);
nNonMax := MAX(dNonSort,dNonSort.pct);
dNonNorm := PROJECT(dNonSort,NormalizeRank(LEFT,COUNTER,nNonMax,-1));

dMerge := dEngNorm + dNonNorm;
nCount := COUNT(dMerge);
dFreq := PROJECT(dMerge,OverallFreq(LEFT,nCount));
dFreqSort := SORT(dFreq,-OverallFreq,-InternalFreq);
nFreqMax := MAX(dFreqSort,dFreqSort.OverallFreq);
dRank := PROJECT(dFreqSort,RankOverall(LEFT,COUNTER,nFreqMax));

EXPORT Trainer	:= dRank:PERSIST('~SENTILYZE::PERSIST::TRAINER::LANGUAGE');