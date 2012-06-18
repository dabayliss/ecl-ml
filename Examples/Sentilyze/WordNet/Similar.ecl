/*****************************************************
* WordNet 3.0 Copyright 2006 by Princeton University.
******************************************************/

EXPORT Similar := MODULE
	EXPORT Layout	:= RECORD
		UNSIGNED4	SynsetId1;
		UNSIGNED4	SynsetId2;
	END;

	EXPORT File	:= DATASET('~SENTILYZE::WORDNET::SIMILAR',Layout,CSV);
END;