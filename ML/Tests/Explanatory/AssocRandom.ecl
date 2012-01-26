IMPORT ML;

TestSize := 100000;
CoOccurs := TestSize/1000;

a1 := ML.Distribution.Poisson(5,100); 
b1 := ML.Distribution.GenData(TestSize,a1,1); // Field 1 Uniform
a2 := ML.Distribution.Poisson(3,100);
b2 := ML.Distribution.GenData(TestSize,a2,2);
a3 := ML.Distribution.Poisson(3,100);
b3 := ML.Distribution.GenData(TestSize,a3,3);

D := b1+b2+b3; // This is the test data
// Now construct a fourth column which is a function of column 1
B4 := PROJECT(b1,TRANSFORM(ML.Types.NumericField, SELF.Number:=4, SELF.Value:=LEFT.Value * 2, SELF.Id := LEFT.id));
																													 
AD0 := PROJECT(ML.Discretize.ByRounding(B1+B2+B3+B4),ML.Types.ItemElement);
// Remove duplicates from bags (fortunately - the generation allows this to be local)
AD := DEDUP( SORT( AD0, ID, Value, LOCAL ), ID, Value, LOCAL );

ASSO := ML.Associate(AD,CoOccurs);
T1 := TOPN(ASSO.Apriori3,50,-Support);
T1;
//ASSO.AprioriN(3,3); -- Known issue in AprioriN presently
T2 := TOPN(ASSO.EclatN(3,3),50,-Support);
T2