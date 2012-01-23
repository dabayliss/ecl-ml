IMPORT ML;
IMPORT ML.Types AS Types;
IMPORT ML.Cluster.DF AS DF;
IMPORT VL;

UNSIGNED4 InDocumentCount:=1000 :STORED('DocumentCount');
UNSIGNED2 InCentroidCount:=50   :STORED('CentroidCount');
UNSIGNED1 InIterations:=20      :STORED('NumberOfIterations');

lOutput:={STRING CHARTELEMENTTYPE;STRING s;};

ML.Types.NumericField CreateElements(UNSIGNED iRows,UNSIGNED iFields=2,UNSIGNED iBeginAt=1,iMaxVal=1000):=FUNCTION
  d01:=DATASET([{0,0,0}],ML.Types.NumericField);
  d02:=NORMALIZE(d01,iRows*iFields,TRANSFORM(ML.Types.NumericField,SELF.id:=((COUNTER-1)/iFields+1)+(iBeginAt-1);SELF.number:=(COUNTER-1)%iFields+1;SELF.value:=RANDOM()%iMaxVal;));
  RETURN d02;
END;

KMeansNAsArray(DATASET(Types.NumericField) d01,DATASET(Types.NumericField) d02,UNSIGNED i,DF.Default fDist=DF.Euclidean):=FUNCTION
  KMeans:=ML.Cluster.KMeans(d01,d02,i);
  dNewPositions:=KMeans.AllResults;
  dNormalized:=SORT(NORMALIZE(dNewPositions,KMeans.Convergence,TRANSFORM({UNSIGNED i;Types.NumericField;STRING s;},SELF.i:=COUNTER;SELF.value:=LEFT.values[COUNTER];SELF.s:=(STRING)SELF.value;SELF:=LEFT;)),i,id,number);
  d01WithS:=TABLE(d01,{d01;STRING s:=(STRING)value;});
  dDocumentsRolled:=ROLLUP(SORT(d01WithS,id,number),LEFT.id!=-RIGHT.id,TRANSFORM(RECORDOF(d01WithS),SELF.s:=LEFT.s+IF(LEFT.number<RIGHT.number,',','],[')+RIGHT.s;SELF:=RIGHT;));
  dCentroidsRolled:=ROLLUP(dNormalized,LEFT.i!=-RIGHT.i,TRANSFORM(RECORDOF(dNormalized),SELF.s:=LEFT.s+IF(LEFT.i=RIGHT.i,IF(LEFT.number<RIGHT.number,',','],['),']],[[')+RIGHT.s;SELF:=RIGHT;));
  sCentroids:='var vertices=[[['+dCentroidsRolled[1].s+']]];';
  sDocuments:='var documents=[['+dDocumentsRolled[1].s+']];';
  RETURN DATASET([{'DATA',sDocuments},{'DATA',sCentroids}],lOutput);
END;

dData:=CreateElements(InDocumentCount);
dCentroids:=CreateElements(InCentroidCount,,InDocumentCount+1);
KMeans:=ML.Cluster.KMeans(dData,dCentroids,InIterations);
dKMeansData:=KMeansNAsArray(dData,dCentroids,InIterations);

sChartName:='D3Voronoi_test';
dWithChartCall:=dKMeansData+DATASET([{'CHARTCALL',VL.D3Templates.VoronoiDynamic(sChartName)}],lOutput);
OUTPUT(dWithChartCall,NAMED(sChartName));