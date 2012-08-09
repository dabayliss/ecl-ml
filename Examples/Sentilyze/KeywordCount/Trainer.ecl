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

	NegaString	:= '~SENTILYZE::TRAINER::NEGASEED';
	dNegaWords	:= DATASET(NegaString,Sentilyze.Types.WordType,CSV);
	dNegaExpand	:= Sentilyze.WordNet.Query.Expand(dNegaWords);
	dNegaStrip	:= Sentilyze.PreProcess.FromWordNet(dNegaExpand);
	dNegaDedup	:= DEDUP(SORT(dNegaStrip,word),LEFT.word = RIGHT.word);
	EXPORT Negative		:= dNegaDedup:PERSIST('~SENTILYZE::PERSIST::TRAINER::NEGAWORDS');

	PosiString	:= '~SENTILYZE::TRAINER::POSISEED';
	dPosiWords	:= DATASET(PosiString,Sentilyze.Types.WordType,CSV);
	dPosiExpand	:= Sentilyze.WordNet.Query.Expand(dPosiWords);
	dPosiStrip	:= Sentilyze.PreProcess.FromWordNet(dPosiExpand);
	dPosiDedup	:= DEDUP(SORT(dPosiStrip,word),LEFT.word = RIGHT.word);
	EXPORT Positive := dPosiDedup:PERSIST('~SENTILYZE::PERSIST::TRAINER::POSIWORDS');
END;