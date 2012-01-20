IMPORT ML;

TestSize := 10000000;

a1 := ML.Distribution.Normal(5,5); 
b1 := ML.Distribution.GenData(TestSize,a1,1);
a2 := ML.Distribution.Normal(1000,10);
b2 := ML.Distribution.GenData(TestSize,a2,2);
a3 := ML.Distribution.Normal(100,20);
b3 := ML.Distribution.GenData(TestSize,a3,3);

D := b1+b2+b3 : PERSIST('temp::tree_data');
C := ML.Trees.KdTree(D,10);
C.Splits;
C.Partitioned;
C.Counts;
C.Extents;