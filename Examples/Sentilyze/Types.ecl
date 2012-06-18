/**********************************************
* SENTILYZE: TYPES
* DESCRIPTION: Contains commonly used record 
* structures.
***********************************************/
EXPORT Types := MODULE
	EXPORT	TweetType	:= RECORD
		STRING tweet;
	END;
	
	EXPORT WordType	:= RECORD
		STRING word;
	END;
	
	EXPORT SentimentType	:= RECORD
		UNSIGNED id;
		STRING	tweet;
		INTEGER1	sentiment;
	END;
	
	EXPORT LanguageType	:= RECORD
		UNSIGNED 	id;
		STRING		tweet;
		INTEGER1	language;
	END;
END;