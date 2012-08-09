/**********************************************
* SENTILYZE: PRE-PROCESSING MODULE
* DESCRIPTION: Pre-processes noisy data for 
* sentiment classification
***********************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT std.Str as Str;
IMPORT ML;

EXPORT PreProcess := MODULE
	SHARED CleanTweet(STRING s)	:= FUNCTION
		sRemoveUsernames	:= REGEXREPLACE('[@]+([A-Za-z0-9_]+)',s,'');
		sRemoveLinks			:= REGEXREPLACE('[A-Za-z]+://[A-Za-z0-9_]+.[A-Za-z0-9_:%&~\?/.=]+',sRemoveUsernames,'');
		sCompressRepeats	:= REGEXREPLACE('([A-Za-z]{1})\\1{3,}',sRemoveLinks,'$1$1$1');
		sCompressPunct		:= REGEXREPLACE('([^\\w\\s])',sCompressRepeats,'');
		sCompressSpaces		:= REGEXREPLACE('([\\s]{2,})',sCompressPunct,' ');
		sRemoveExtra			:= REGEXREPLACE('(ha|ja|hee|ho|hu|je|ya){3,}',sCompressSpaces,'$1$1');
		RETURN	sRemoveExtra;
	END;
	
	SHARED StripHashtag(STRING s)	:= FUNCTION
		sRemoveHashtags	:= REGEXREPLACE('[#]+([A-Za-z0-9_]{2,})',s,'');
		RETURN sRemoveHashtags;
	END;
	
	SHARED RemoveRT(DATASET(Sentilyze.Types.TweetType) T)	:= FUNCTION
		Sentilyze.Types.TweetType SkipRT(Sentilyze.Types.TweetType W)	:= TRANSFORM
			SELF.tweet	:= IF(REGEXFIND('\\<(RT|MT)',W.tweet,NOCASE),SKIP,W.tweet);
		END;
		
		TSort		:= SORT(T,tweet);
		TDedup	:= DEDUP(TSort,LEFT.tweet = RIGHT.tweet);
		RETURN	PROJECT(TDedup,SkipRT(LEFT));	
	END;
	
		SHARED RemoveBlank(DATASET(Sentilyze.Types.TweetType) T)	:= FUNCTION
		Sentilyze.Types.TweetType SkipBlank(Sentilyze.Types.TweetType W)	:= TRANSFORM
			SELF.tweet	:= IF((W.tweet = ''),SKIP,W.tweet);
		END;
		
		RETURN	PROJECT(T,SkipBlank(LEFT));
	END;
	
	SHARED StripPOS(STRING s)	:= FUNCTION
		sStripPOS	:=	REGEXREPLACE('\\([A-Z]\\)',s,'');
		RETURN sStripPOS;
	END;

	SHARED ConvertRaw(DATASET(Sentilyze.Types.TweetType) T)	:= FUNCTION
		ML.Docs.Types.Raw	Convert(Sentilyze.Types.TweetType W, UNSIGNED C)	:= TRANSFORM
			SELF.id		:= C;
			SELF.txt	:= W.tweet;
		END;
		
		RETURN PROJECT(T,Convert(LEFT,COUNTER));
	END;
	
	/*
		For Analysis Pre-processes noisy tweets for Sentiment Analysis
			Removes
			1) Twitter artifacts: Usernames, Links, Repeated Letters and Strings, Hashtags
	*/
	EXPORT ForAnalysis(DATASET(Sentilyze.Types.TweetType) T)	:= FUNCTION
		TClean		:= PROJECT(T,TRANSFORM(Sentilyze.Types.TweetType,SELF.tweet := CleanTweet(LEFT.tweet)));
		TNoHash		:= PROJECT(TClean,TRANSFORM(Sentilyze.Types.TweetType,SELF.tweet := StripHashtag(LEFT.tweet)));
		TNoBlank	:= RemoveBlank(TNoHash);
		RETURN	TNoBlank;
	END;
	
	/*
		For Training Pre-processes noisy tweets to train Classifiers
		Removes:
			1) Twitter Artifacts: Usernames, Links, Repeated Letters and Strings, Hashtags
			2) Retweets and other duplicate tweets
	*/
	EXPORT ForTraining(DATASET(Sentilyze.Types.TweetType) T)	:= FUNCTION
		TClean		:= PROJECT(T,TRANSFORM(Sentilyze.Types.TweetType,SELF.tweet := CleanTweet(LEFT.tweet)));
		TNoHash		:= PROJECT(TClean,TRANSFORM(Sentilyze.Types.TweetType,SELF.tweet := StripHashtag(LEFT.tweet)));
		TNoRT			:= RemoveRT(TNoHash);
		TNoBlank	:= RemoveBlank(TNoRT);
		RETURN TNoBlank;
	END;
	
	/*
		FromWordNet Pre-procsses WordNet Synsets for use in Classification
		Removes:
			1) Part of Speech (POS) tags
	*/ 
	EXPORT FromWordNet(DATASET(Sentilyze.Types.WordType) W)	:= FUNCTION
		RETURN PROJECT(W,TRANSFORM(Sentilyze.Types.WordType,SELF.word := StripPOS(Str.ToUpperCase(LEFT.word))));
	END;
	
	/*
		ToRaw	Converts a TweetType record set to Raw (ML.Docs.Types.Raw)
	*/	
	EXPORT ToRaw(DATASET(Sentilyze.Types.TweetType) T)	:=	FUNCTION
		RETURN ConvertRaw(T);
	END;
	
END;