#Sentilyze, Twitter Sentiment Classification with HPCC

##About Sentilyze
Sentilyze uses HPCC Systems and its ML-Library to classify tweets with positive or negative sentiment.

----------

##Sentilyze Contents

###Keyword Count Classifier
Sentiment is determined by counting the number of negative and positive words in a tweet. The tweet is classified as the polarity with the highest word count.

###Naïve Bayes Classifier
Sentiment is determined by a supervised, multinomial (bag-of-words) Naïve Bayes Classifer.

###Language Classifier
Filters tweets by language using Rank Ordered Unigrams ([Ahmed et al., Pace University](http://www.csis.pace.edu/~ctappert/srd2004/paper12.pdf))

----------

##Sentilyze Requirments
- Machine Learning Library 
- Synset and Similar data from [Princeton's WordNet](http://wordnet.princeton.edu "Princeton's Wordnet")
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

####Language Classifier
Currently, filtering tweets by language is unavailable using Twitter's Streaming API. Twitter's Search API has language-filtering capabilities but results may vary. Therefore, it may be necessary for language-specific sentiment analysis to filter out tweets that are not in the target language(s). 

The Language Classifier classifies tweets into two groups, Keep and Filter and returns tweets marked as "Keep". 

#####Training the Language Classifier Walkthrough
Record sets of language(s) to keep and filter are required to train the Language Classifier

- Expand the ***Language*** folder and open ***Trainer.ecl***
- Find "File String Definitions" and replace strings with the appropiate logical file names of trainer datasets. 

####Naïve Bayes Sentiment Classifier

- Expand the ***NaiveBayes*** folder and open ***Model.ecl***
- Find "File String Definitions" and replace strings with the appropiate logical file names of trainer datasets. 

####Keyword Count Sentiment Classifier
Datasets of Positive and Negative words are required to train the Keyword Count Classifier

#####Generating Word Lists

***Generate.ecl*** can be used to create lists of seed words to be used for training the Keyword Count classifier. It uses two methods of weighting words, Term Frequency-Inverse Document Frequency (TF-IDF) and Mutual Information. 

> IMPORT Sentilyze;

> tweetsPositive := DATASET('~SENTILYZE::POSITIVE',Sentilyze.Types.TweetType,CSV);

> tweetsNegative := DATASET('~SENTILYZE::NEGATIVE',Sentilyze.Types.TweetType,CSV);

> rawPositive := Sentilyze.PreProcess.ToRaw(tweetsPositive);

> rawNegative := Sentilyze.PreProcess.ToRaw(tweetsNegative);

> processPositive := Sentilyze.PreProcess.ForTraining(rawPositive);

> processNegative := Sentilyze.PreProcess.ForTraining(rawNegative);

> positiveWordsTfidf := Sentilyze.KeywordCount.Generate(processPositive,200).Keywords_tfidf;

> negativeWordsTfidf := Sentilyze.KeywordCount.Generate(processNegative,200).Keywords_tfidf;

> sentimentWordsMI := Sentilyze.KeywordCount.Generate(processPositive,200).Keywords_MI(processNegative);

>OUTPUT(positiveWordsTfidf,all,NAMED('PositiveTfidf_Words'));

>OUTPUT(negativeWordsTfidf,all,NAMED('NegativeTfidf_Words'));

>OUTPUT(sentimentWordsMI,all,NAMED('SentimentMI_Words'));

#####Training Keyword Count Classifier
- Expand the ***KeywordCount*** folder and open ***Trainer.ecl***
- Find "File String Definitions" and replace strings with the appropiate logical file names of trainer datasets. 

----------

###Classifying Tweets
Below is an example of a dataset of tweets that are classified using both Keyword Count and Naïve Bayes sentiment classifiers

> IMPORT Sentilyze;

>Tweets := DATASET('~SENTILYZE::TWEETS',Sentilyze.Types.TweetType.CSV);

>rawTweets := Sentilyze.PreProcess.ToRaw(Tweets);

>processTweets := Sentilyze.PreProcess.ForAnalysis(rawTweets)

>kcSentiment := Sentilyze.KeywordCount.Classify(processTweets);

>nbSentiment := Sentilyze.NaiveBayes.Classify(processTweets);

>OUTPUT(kcSentiment,NAMED('TwitterSentiment_KeywordCount'));

>OUTPUT(nbSentiment,NAMED('TwitterSentiment_NaiveBayes'));

----------

##Sentilyze Functions Appendix

###Language Classifier (Sentilyze.Language)

####Classify
Sentilyze.Language.Classify(*recordset[,language]*)

<table>
<tr>
<td>recordset</td><td>The set of <em>Raw</em> (ML.Docs.Types.Raw) records to process</td>
</tr>
<tr>
<td>language</td><td>An integer representing the group of tweets to return. 1 = 'Keep', -1 'Discard'. Default: 1</td>
</tr>
<tr>
<td>Return:</td><td><strong><em>Classify</em></strong> returns a <em>Raw</em> record set</td>
</tr>
</table>

----------

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

####ForAnalysis
ForAnalysis(*recordset*)
<table>
<tr>
<td>recordset</td><td>The set of <em>Raw</em> (ML.Docs.Types.Raw) records to process</td>
</tr>
<tr>
<td>Return:</td><td><strong><em>ForAnalysis</em></strong> returns a Raw record set.</td>
</tr>
</table>

The ***ForAnalysis*** function replaces:

- Repeated Letters and Strings (omggggg caaaaatssss to omggg caaatsss; hahahahaha to hahaha)

- Twitter artifacts: Usernames, Links, Hashtags with 'TWITTERUSER', 'TWITTERLINK', 'TWITTERHASHTAG'

####ForTraining
ForTraining(*recordset*)
<table>
<tr>
<td>recordset</td><td>The set of <em>Raw</em> (ML.Docs.Types.Raw) records to process</td>
</tr>
<tr>
<td>Return:</td><td><strong><em>ForTraining</em></strong> returns a <em>Raw</em> record set.</td>
</tr>
</table>

The ***ForTraining*** function replaces
- Repeated Letters and Strings (omggggg caaaaatssss to omggg caaatsss; hahahahaha to hahaha)

- Twitter artifacts: Usernames, Links, Hashtags with 'TWITTERUSER', 'TWITTERLINK', 'TWITTERHASHTAG'

and removes

- retweets (Tweets marked with RT/MT) and duplicate tweets

####ToRaw
ToRaw(*recordset*)
<table>
<tr>
<td><em>recordset</em></td><td>The set of <em>TweetType</em> (Sentilyze.Types.TweetType) records to process</td>
</tr>
<tr>
<td>Return:</td><td><strong><em>ToRaw</em></strong> returns a <em>Raw</em> (ML.Docs.Types.Raw) record set</td>
</tr>
</table>

----------

###WordNet Query Module (Sentilyze.WordNet.Query)
####GetSimilar
Sentilyze.WordNet.Query.GetSimilar(*recordset*)
<table>
<tr>
<td><em>recordset</em></td><td>The set of <em>WordType</em> (Sentilyze.Types.WordType) records to process.</td>
</tr>
<td>Return:</td><td><strong><em>GetSimilar</em></strong> returns a <em>WordType</em> record set.</td>
</tr>
</table>

####ExpandList
Sentilyze.WordNet.Query.ExpandList(*recordset*)
<table>
<tr>
<td><em>recordset</em></td><td>The set of <em>WordType</em> (Sentilyze.Types.WordType) records to process.</td>
</tr>
<td>Return:</td><td><strong><em>ExpandList</em></strong> returns a <em>WordType</em> record set.</td>
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