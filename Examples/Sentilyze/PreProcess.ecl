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
		sRemoveUsernames := REGEXREPLACE('[@]+([A-Za-z0-9_]+)',s,'TWITTERUSERNAME');
		sRemoveHashtags := REGEXREPLACE('[#]+([A-Za-z0-9_]{2,})',sRemoveUsernames,'TWITTERHASHTAG');
		sRemoveLinks := REGEXREPLACE('[A-Za-z]+://[A-Za-z0-9_]+.[A-Za-z0-9_:%&~\?/.=]+',sRemoveHashtags,'TWITTERLINK');
		sCompressRepeats := REGEXREPLACE('([A-Za-z]{1})\\1{3,}',sRemoveLinks,'$1$1$1');
		sCompressSpaces := REGEXREPLACE('([\\s]{2,})',sCompressRepeats,' ');
		sRemoveExtra := REGEXREPLACE('(ha|ja|hee|ho|hu|je|ya){3,}',sCompressSpaces,'$1$1');
		RETURN sRemoveExtra;
	END;

	SHARED RemoveRT(DATASET(ML.Docs.Types.Raw) T)	:= FUNCTION
		ML.Docs.Types.Raw SkipRT(ML.Docs.Types.Raw W) := TRANSFORM
			SELF.txt := IF(REGEXFIND('\\<(RT|MT)',W.txt,NOCASE),SKIP,W.txt);
			SELF := W;
		END;

		TSort := SORT(T,txt);
		TDedup := DEDUP(TSort,LEFT.txt = RIGHT.txt);
		RETURN PROJECT(TDedup,SkipRT(LEFT));
	END;

	SHARED RemoveBlank(DATASET(ML.Docs.Types.Raw) T)	:= FUNCTION
		ML.Docs.Types.Raw SkipBlank(ML.Docs.Types.Raw W)	:= TRANSFORM
			SELF.txt := IF((W.txt = ''),SKIP,W.txt);
			SELF := W;
		END;

		RETURN PROJECT(T,SkipBlank(LEFT));
	END;

	SHARED StripPOS(STRING s)	:= FUNCTION
		sStripPOS	:=	REGEXREPLACE('\\([A-Z]\\)',s,'');
		RETURN sStripPOS;
	END;

	SHARED ConvertRaw(DATASET(Sentilyze.Types.TweetType) T)	:= FUNCTION
		ML.Docs.Types.Raw	Convert(Sentilyze.Types.TweetType W, UNSIGNED C)	:= TRANSFORM
			SELF.id := C;
			SELF.txt := W.tweet;
		END;

		RETURN PROJECT(T,Convert(LEFT,COUNTER));
	END;

	/*
		For Analysis Pre-processes noisy tweets for Sentiment Analysis
			Removes:
			1) Repeated Letters and Strings
			Replaces:
			1) Twitter artifacts: Usernames, Links, Hashtags with 'TWITTERUSER', 'TWITTERLINK', 'TWITTERHASHTAG'
	*/
	EXPORT ForAnalysis(DATASET(ML.Docs.Types.Raw) T)	:= FUNCTION
		TClean := PROJECT(T,TRANSFORM(ML.Docs.Types.Raw,SELF.txt := CleanTweet(LEFT.txt);SELF := LEFT));
		TNoBlank := RemoveBlank(TClean);
		RETURN TNoBlank;
	END;

	/*
		For Training Pre-processes noisy tweets to train Classifiers
		Removes:
			1) Repeated Letters and Strings
			2) Retweets and other duplicate tweets
		Replaces with tags:
			1) Twitter Artifacts: Usernames, Links, Hashtags with 'TWITTERUSER', 'TWITTERLINK', 'TWITTERHASHTAG'
	*/
	EXPORT ForTraining(DATASET(ML.Docs.Types.Raw) T)	:= FUNCTION
		TClean := PROJECT(T,TRANSFORM(ML.Docs.Types.Raw,SELF.txt := CleanTweet(LEFT.txt);SELF := LEFT));
		TNoRT := RemoveRT(TClean);
		TNoBlank := RemoveBlank(TNoRT);
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