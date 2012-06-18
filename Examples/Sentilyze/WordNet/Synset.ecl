/**************************************************
* SENTILYZE: WORDNET SYNSET MODULE
* DESCRIPTION: The basic building block of the
* WordNet Database. 
**************************************************/
EXPORT Synset := MODULE
	SHARED	rRawSynset := RECORD
		UNSIGNED4 SynsetId;
		UNSIGNED1 WordId;
		STRING Word;
		STRING1 Pos;
		UNSIGNED1 SenseNumber;
		UNSIGNED1 TagCount;
	END;

	SHARED	RawData := DATASET('~SENTILYZE::WORDNET::SYNSET',rRawSynset,CSV);
	
	EXPORT	Layout	:= RECORD
		STRING Word := RawData.Word;
		UNSIGNED4 SynsetId := RawData.SynsetId;
	END;

	EXPORT File := TABLE(RawData,Layout):PERSIST('~SENTILYZE::PERSIST::WORDNET::SYNSET'); 
END;