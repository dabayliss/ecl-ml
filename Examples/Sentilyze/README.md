#Sentilyze, Twitter Sentiment Classification with HPCC

##About Sentilyze
Sentilyze uses HPCC Systems and its ML-Library to classify tweets with positive or negative sentiment.

----------

##Sentilyze Contents

###Keyword Count Classifier
Sentiment is determined by counting the number of negative and positive words in a tweet. The tweet is classified as the polarity with the highest word count.

###Naïve Bayes Classifier
Sentiment is determined by a supervised, multinomial (bag-of-words) Naïve Bayes Classifer.

----------

##Sentilyze Requirments
- Machine Learning Library 
- Tweets

###Aqcuiring Tweets From Twitter

####Format
The default format for files containing tweets is a Comma Separated Values (CSV) file of twitter statuses terminated with newline characters.

####Spraying CSV Files
The parameters for a properly formatted CSV file are:

- Separator: No Separator
- Line Terminator: \n, \r\n

----------

##Using Sentilyze

###Training Classifiers

####Naïve Bayes Sentiment Classifier
- In Strings.ecl, under "Naive Bayes Sentiment Classifier" replace strings with the appropiate logical file names of trainer datasets. The ***BayesModel*** and ***BayesVocab*** will be created when the Naive Bayes Sentiment Classifier is run for the first time.

####Keyword Count Sentiment Classifier
Datasets of Positive and Negative words are required to train the Keyword Count Classifier

#####Generating Word Lists

***Generate.ecl*** can be used to create lists of keywords to be used with the Keyword Count classifier. It uses two methods of weighting words, Term Frequency-Inverse Document Frequency (TF-IDF) and Mutual Information. 

> IMPORT Sentilyze;

> tweetsPositive := DATASET('~SENTILYZE::POSITIVE',Sentilyze.Types.TweetType,CSV);

> tweetsNegative := DATASET('~SENTILYZE::NEGATIVE',Sentilyze.Types.TweetType,CSV);

> rawPositive := Sentilyze.PreProcess.ConvertToRaw(tweetsPositive);

> rawNegative := Sentilyze.PreProcess.ConvertToRaw(tweetsNegative);

> processPositive := Sentilyze.PreProcess.RemoveTraining(rawPositive);

> processNegative := Sentilyze.PreProcess.RemoveTraining(rawNegative);

> positiveWordsTfidf := Sentilyze.KeywordCount.Generate(processPositive,200).Keywords_tfidf;

> negativeWordsTfidf := Sentilyze.KeywordCount.Generate(processNegative,200).Keywords_tfidf;

> sentimentWordsMI := Sentilyze.KeywordCount.Generate(processPositive,200).Keywords_MI(processNegative);

>OUTPUT(positiveWordsTfidf,all,NAMED('PositiveTfidf_Words'));

>OUTPUT(negativeWordsTfidf,all,NAMED('NegativeTfidf_Words'));

>OUTPUT(sentimentWordsMI,all,NAMED('SentimentMI_Words'));

#####Training Keyword Count Classifier
- In Strings.ecl, under "KeywordCount Sentiment Classifier" replace strings with the appropiate logical file names of keyword datasets. 

----------

###Classifying Tweets
Below is an example of a dataset of tweets that are classified using both Keyword Count and Naïve Bayes sentiment classifiers

> IMPORT Sentilyze;

>Tweets := DATASET('~SENTILYZE::TWEETS',Sentilyze.Types.TweetType.CSV);

>rawTweets := Sentilyze.PreProcess.ConvertToRaw(Tweets);

>processTweets := Sentilyze.PreProcess.RemoveAnalysis(rawTweets)

>kcSentiment := Sentilyze.KeywordCount.Classify(processTweets);

>nbSentiment := Sentilyze.NaiveBayes.Classify(processTweets);

>OUTPUT(kcSentiment,NAMED('TwitterSentiment_KeywordCount'));

>OUTPUT(nbSentiment,NAMED('TwitterSentiment_NaiveBayes'));

----------

##Sentilyze Functions Appendix

###Keyword Count Sentiment Classifier (Sentilyze.KeywordCount)

####Generate

#####Keywords_TFIDF
Sentilyze.KeywordCount.Generate(*recordset[,nWords]*).Keywords_TFIDF
<table>
<tr>
<td>recordset</td><td>The set of <em>Raw</em> (ML.Docs.Types.Raw) records to process</td>
</tr>
<tr>
<td>nWords</td><td>(Optional) An integer representing the maximum number of keywords in the returned set. Default: 100</td>
</tr>
<tr>
<td>Return:</td><td><strong><em>Keywords_TFIDF</em></strong> returns a <em>WordType</em> (Sentilyze.Types.WordType) record set.</td>
</tr>
</table>
The ***Keywords_TFIDF*** attribute returns a list of keywords sorted by descending TF-IDF weight.

#####Keywords_MI
Sentilyze.KeywordCount.Generate(*recordset[,nWords]*).Keywords_MI(*otherset*[,*threshold*[,*units*]])
<table>
<tr>
<td>recordset</td><td>A set of <em>Raw</em> (ML.Docs.Types.Raw) records to process</td>
</tr>
<tr>
<td>nWords</td><td>(Optional) An integer representing the maximum number of keywords in the returned set. Default: 100</td>
</tr>
<tr>
<td>otherset</td><td>A set of <em>Raw</em> (ML.Docs.Types.Raw) records to process</td>
</tr>
<tr>
<td>threshold</td><td>(Optional) An integer representing the minimum document frequency for a word to be included in the result set. Default:0</td>
</tr>
<tr>
<td>units</td><td>(Optional) An integer representing the unit of measurement for mutual information. Default: 2 (bits)</td>
</tr>
<tr>
<td>Return:</td><td><strong><em>Keywords_MI</em></strong> returns a <em>WordType</em> (Sentilyze.Types.WordType) record set.</td>
</tr>
</table>
The ***Keywords_MI*** attribute returns a list of keywords sorted by descending Mutual Information weight.

####Classify
Sentilyze.KeywordCount.Classify(*recordset*)
<table>
<tr><td>recordset</td><td>The set of <em>Raw</em> (ML.Docs.Types.Raw) records to process</td>
</tr>
<td>Return: </td><td><strong><em>Classify</em></strong> returns a SentimentType (Sentilyze.Types.SentimentType) record set.</td>
</tr>
</table>
----------
###Naïve Bayes Sentiment Classifier (Sentilyze.NaiveBayes)
####Classify
Sentilyze.NaiveBayes.Classify(*recordset*)
<table>
<tr><td>recordset</td><td>The set of <em>Raw</em> (ML.Docs.Types.Raw) records to process</td>
</tr>
<td>Return: </td><td><strong><em>Classify</em></strong> returns a SentimentType (Sentilyze.Types.SentimentType) record set.</td>
</tr>
</table>

----------

###Pre-Processing Module (Sentilyze.PreProcess)

####ReplaceAnalysis and RemoveAnalysis
ReplaceAnalysis(*recordset*) or RemoveAnalysis(*recordset*)
<table>
<tr>
<td>recordset</td><td>The set of <em>Raw</em> (ML.Docs.Types.Raw) records to process</td>
</tr>
<tr>
<td>Return:</td><td><strong><em>ReplaceAnalysis</em></strong> and <em><strong>RemoveAnalysis</strong></em> returns a Raw record set.</td>
</tr>
</table>

The ***ReplaceAnalysis*** function replaces:

- Repeated Letters and Strings (omggggg caaaaatssss to omggg caaatsss; hahahahaha to hahaha)

- Twitter artifacts: Usernames, Links, Hashtags with 'TWITTERUSER', 'TWITTERLINK', 'TWITTERHASHTAG'

The ***RemoveAnalysis*** function removes:

- Twitter artifacts
- Repeated Letters and Strings (omggggg caaaaatssss to omggg caaatsss; hahahahaha to hahaha)

####ReplaceTraining and RemoveTraining
ReplaceTraining(*recordset*) or RemoveTraining(*recordset*)
<table>
<tr>
<td>recordset</td><td>The set of <em>Raw</em> (ML.Docs.Types.Raw) records to process</td>
</tr>
<tr>
<td>Return:</td><td><strong><em>ReplaceTraining</em></strong> and <strong><em>RemoveTraining</em></strong> returns a <em>Raw</em> record set.</td>
</tr>
</table>

The ***ReplaceTraining*** function replaces
- Repeated Letters and Strings (omggggg caaaaatssss to omggg caaatsss; hahahahaha to hahaha)

- Twitter artifacts: Usernames, Links, Hashtags with 'TWITTERUSER', 'TWITTERLINK', 'TWITTERHASHTAG'

and removes

- retweets (Tweets marked with RT/MT) and duplicate tweets

The ***RemoveTraining*** function removes
- Repeated Letters and Strings (omggggg caaaaatssss to omggg caaatsss; hahahahaha to hahaha)

- Twitter artifacts: Usernames, Links, Hashtags

- retweets (Tweets marked with RT/MT) and duplicate tweets


####ConvertToRaw
ConvertToRaw(*recordset*)
<table>
<tr>
<td><em>recordset</em></td><td>The set of <em>TweetType</em> (Sentilyze.Types.TweetType) records to process</td>
</tr>
<tr>
<td>Return:</td><td><strong><em>ConvertToRaw</em></strong> returns a <em>Raw</em> (ML.Docs.Types.Raw) record set</td>
</tr>
</table>

----------

###Sentilyze Record Structures (Sentilyze.Types)

####TweetType
>TweetType := RECORD

>  STRING tweet;

>END;

####WordType 
>WordType := RECORD

> STRING word;

>END;

####SentimentType
Structure of record sets that have been classified with a Sentiment Classifier.

> SentimentType := RECORD

>  UNSIGNED id;

>  STRING tweet;

>  INTEGER1 sentiment;

> END;