IMPORT * FROM ML;
// See http://www.cs.otago.ac.nz/cosc453/student_tutorials/principal_components.pdf
// for plots of the original dataset, and transform vectors
Rec := RECORD
       UNSIGNED rid;
		   REAL X1;  // x coordinates
       REAL X2;  // y coordinates
 END;
                
points := DATASET([{1,2.5,2.4},{2,0.5,0.7},{3,2.2,2.9},{4,1.9,2.2},{5,3.1,3.0},
									{6,2.3,2.7},{7,2.0,1.6},{8,1.0,1.1},{9,1.5,1.6},{10,1.1,0.9}],Rec);
                                                                                                                
// Turn into regular NumericField file (with continuous variables)
ToField(points,O);
X := Types.ToMatrix(O(Number in [1,2])); 
X;
MeanX := Mat.Repmat(Mat.Has(X).MeanCol, Mat.Has(X).Stats.XMax, 1);
MeanX;
Ur := Mat.Pca(X).Ureduce;
OUTPUT(Ur, named('transform_vectors'));
z := Mat.PCA(X).ZComp;
OUTPUT(z, named('final_data'));

OrigX := Mat.Add(Mat.Trans(Mat.Mul(Ur, Mat.Trans(z))), MeanX);
OrigX;
AlmostZero := Mat.Sub(X,OrigX);
OUTPUT(IF(EXISTS(Mat.Thin(AlmostZero)),'Failed','Passed!'),named('Pca_Test'));
