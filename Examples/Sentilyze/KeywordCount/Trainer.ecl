/**********************************************
* SENTILYZE: KEYWORD COUNT CLASSIFIER TRAINER
* DESCRIPTION: takes two WordType record sets
* containing positive and negative seed words
* respectively and expands them using WordNet
* for use in Sentiment Classification
***********************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT std.Str AS Str;

EXPORT Trainer := MODULE
	// FILE STRING DEFINITIONS
	SHARED sNegaSeed := '~SENTILYZE::TRAINER::NEGASEED'; //Logical File Name of Dataset of Negative Seed Words
	SHARED sNegaWords := '~SENTILYZE::PERSIST::TRAINER::NEGAWORDS'; //Logical File Name of Expansion of Negative Seed Words
	SHARED sPosiSeed := '~SENTILYZE::TRAINER::POSISEED'; //Logical File Name of Dataset of Positive Seed Words
	SHARED sPosiWords := '~SENTILYZE::PERSIST::TRAINER::POSIWORDS'; //Logical File Name of Expansion of Positive Seed Words

	dNegaWords := DATASET(sNegaSeed,Sentilyze.Types.WordType,CSV);
	dNegaExpand := Sentilyze.WordNet.Query.Expand(dNegaWords);
	dNegaStrip := Sentilyze.PreProcess.FromWordNet(dNegaExpand);
	dNegaDedup := DEDUP(SORT(dNegaStrip,word),LEFT.word = RIGHT.word);
	EXPORT Negative := dNegaDedup:PERSIST(sNegaWords);

	dPosiWords := DATASET(sPosiSeed,Sentilyze.Types.WordType,CSV);
	dPosiExpand := Sentilyze.WordNet.Query.Expand(dPosiWords);
	dPosiStrip := Sentilyze.PreProcess.FromWordNet(dPosiExpand);
	dPosiDedup := DEDUP(SORT(dPosiStrip,word),LEFT.word = RIGHT.word);
	EXPORT Positive := dPosiDedup:PERSIST(sPosiWords);
END;