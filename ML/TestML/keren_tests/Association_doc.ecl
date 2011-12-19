IMPORT ML;
IMPORT ML.Docs AS Docs;
d11 := DATASET([{'One of the wonderful things about tiggers is tiggers are wonderful things'},
{'It is a little scarey the drivel that enters one\'s mind when given the task of entering random text'},
{'I almost quoted obama; but I considered that I had gotten a little too silly already!'},
{'I would hate to have quoted silly people!'},
{'obama is often quoted'},
{'In Hertford, Hereford and Hampshire Hurricanes hardly ever happen'},
{'In the beginning was the Word and the Word was with God and the Word was God'}],{string r});
d00 := DATASET([{'aa bb cc dd ee'},{'bb cc dd ee ff gg hh ii'},{'bb cc dd ee ff gg hh ii'}, {'dd ee ff'},{'bb dd ee'}],{string r});
d := d11;
d1 := PROJECT(d,TRANSFORM(Docs.Types.Raw,SELF.Txt := LEFT.r));
d2 := Docs.Tokenize.Enumerate(d1);
d3 := Docs.Tokenize.Clean(d2);
d4 := Docs.Tokenize.Split(d3);
lex := Docs.Tokenize.Lexicon(d4);
o1 := Docs.Tokenize.ToO(d4,lex);
o2 := Docs.Trans(O1).WordBag;
lex;
ForAssoc := PROJECT( o2, TRANSFORM(ML.Types.ItemElement,SELF.id := LEFT.id,
SELF.value := LEFT.word ));
ForAssoc;
ML.Associate(ForAssoc,2).Apriori1;
ML.Associate(ForAssoc,2).Apriori2;
ML.Associate(ForAssoc,2).Apriori3;
ML.Associate(ForAssoc,2).AprioriN(40);

//Added - not part of the doc.
ML.Associate(ForAssoc,2).EclatN;
