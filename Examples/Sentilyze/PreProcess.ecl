/**********************************************
* SENTILYZE: PRE-PROCESSING MODULE
* DESCRIPTION: Pre-processes noisy data for 
* sentiment classification
***********************************************/
IMPORT Examples.Sentilyze AS Sentilyze;
IMPORT std.Str as Str;
IMPORT ML;

EXPORT PreProcess := MODULE
	EXPORT RemoveFeatures(STRING tweet) := FUNCTION
		RemoveUsernames := REGEXREPLACE('[@]+([A-Za-z0-9_]+)',tweet,'');
		RemoveHashtags := REGEXREPLACE('[#]+([A-Za-z0-9_]{2,})',RemoveUsernames,'');
		RemoveLinks := REGEXREPLACE('[A-Za-z]+://[A-Za-z0-9_]+.[A-Za-z0-9_:%&~\?/.=]+',RemoveHashtags,'');
		RemoveRepeat := REGEXREPLACE('([A-Za-z]{1})\\1{3,}',RemoveLinks,'$1$1$1');
		RemoveExtra := REGEXREPLACE('(ha|ja|hee|ho|hu|je|ya){3,}',RemoveRepeat,'$1$1');
		RETURN RemoveExtra;
	END;

	EXPORT ReplaceFeatures(STRING tweet) := FUNCTION
		ReplaceUsernames := REGEXREPLACE('[@]+([A-Za-z0-9_]+)',tweet,'TWITTERUSERNAME');
		ReplaceHashtags := REGEXREPLACE('[#]+([A-Za-z0-9_]{2,})',ReplaceUsernames,'TWITTERHASHTAG');
		ReplaceLinks := REGEXREPLACE('[A-Za-z]+://[A-Za-z0-9_]+.[A-Za-z0-9_:%&~\?/.=]+',ReplaceHashtags,'TWITTERLINK');
		ReplaceRepeat := REGEXREPLACE('([A-Za-z]{1})\\1{3,}',ReplaceLinks,'$1$1$1');
		ReplaceExtra := REGEXREPLACE('(ha|ja|hee|ho|hu|je|ya){3,}',ReplaceRepeat,'$1$1');
		RETURN ReplaceExtra;
	END;

	EXPORT RemoveRT(DATASET(ML.Docs.Types.Raw) T) := FUNCTION
		RETURN PROJECT(T,TRANSFORM(ML.Docs.Types.Raw,SELF.txt := IF(REGEXFIND('\\<(RT|MT)',LEFT.txt,NOCASE),SKIP,LEFT.txt); SELF := LEFT));
	END;

	EXPORT RemoveBlank(DATASET(ML.Docs.Types.Raw) T) := FUNCTION
		RETURN PROJECT(T,TRANSFORM(ML.Docs.Types.Raw,SELF.txt :=  IF((LEFT.txt = ''),SKIP,LEFT.txt); SELF := LEFT));
	END;

	EXPORT ConvertToRaw(DATASET(Sentilyze.Types.TweetType) T)	:= FUNCTION
		RETURN PROJECT(T,TRANSFORM(ML.Docs.Types.Raw,SELF.id := COUNTER;SELF.txt := LEFT.tweet));
	END;

	// For Analysis Pre-processes noisy tweets for Sentiment Analysis
	EXPORT RemoveAnalysis(DATASET(ML.Docs.Types.Raw) T)	:= FUNCTION
		Clean := PROJECT(T,TRANSFORM(ML.Docs.Types.Raw,SELF.txt := RemoveFeatures(LEFT.txt);SELF := LEFT));
		Blank := RemoveBlank(Clean);
		RETURN Blank;
	END;

	EXPORT ReplaceAnalysis(DATASET(ML.Docs.Types.Raw) T)	:= FUNCTION
		Clean := PROJECT(T,TRANSFORM(ML.Docs.Types.Raw,SELF.txt := ReplaceFeatures(LEFT.txt);SELF := LEFT));
		Blank := RemoveBlank(Clean);
		RETURN Blank;
	END;

	// For Training Pre-processes noisy tweets to train Classifiers
	EXPORT RemoveTraining(DATASET(ML.Docs.Types.Raw) T)	:= FUNCTION
		Clean := PROJECT(T,TRANSFORM(ML.Docs.Types.Raw,SELF.txt := RemoveFeatures(LEFT.txt); SELF := LEFT));
		RT := RemoveRT(Clean);
		Blank := RemoveBlank(RT);
		RETURN Blank;
	END;

	EXPORT ReplaceTraining(DATASET(ML.Docs.Types.Raw) T)	:= FUNCTION
		Clean := PROJECT(T,TRANSFORM(ML.Docs.Types.Raw,SELF.txt := ReplaceFeatures(LEFT.txt);SELF := LEFT));
		RT := RemoveRT(Clean);
		Blank := RemoveBlank(RT);
		RETURN Blank;
	END;

END;