IMPORT ML.Docs AS Docs;
EXPORT KMeans:=MODULE

EXPORT macCalculateMeans(dDocuments,dCentroids,sDistanceFunction,dResult):=MACRO
  #UNIQUENAME(dClosest)
  Docs.Distance.macCalculateDistance(dDocuments,dCentroids,sDistanceFunction,%dClosest%,TRUE);
  
  // Grouping by ref_id gives us the number of documents that are assigned to
  // each centroid
  #UNIQUENAME(dClusterCounts)
  %dClusterCounts%:=TABLE(%dClosest%,{cen_id;Docs.Types.t_Value c:=(Docs.Types.t_Value)COUNT(GROUP);},cen_id);

  // Join the document matrix to the table of closest values to assign each
  // document to the appropriate centroid.  Sorting and rolling on x and y
  // gives us the sum of all values on each axis.
  #UNIQUENAME(dClustered)
  %dClustered%:=SORT(JOIN(DISTRIBUTE(dDocuments,id),DISTRIBUTE(%dClosest%,doc_id),LEFT.id=RIGHT.doc_id,TRANSFORM(Docs.Types.DocumentMatrix,SELF.id:=RIGHT.cen_id;SELF:=LEFT;SELF:=RIGHT;),LOCAL),RECORD,LOCAL);
  #UNIQUENAME(dRolled)
  %dRolled%:=ROLLUP(%dClustered%,TRANSFORM(Docs.Types.DocumentMatrix,SELF.value:=LEFT.value+RIGHT.value;SELF:=LEFT;),id,word_id,LOCAL);
  
  // Joining the rolled table to the cluster counts table gives us the
  // denominators we need to calculate the new means on each axis.
  #UNIQUENAME(dJoined)
  %dJoined%:=JOIN(%dRolled%,%dClusterCounts%,LEFT.id=RIGHT.cen_id,TRANSFORM(Docs.Types.DocumentMatrix,SELF.value:=LEFT.value/RIGHT.c;SELF:=LEFT;),LOOKUP);
  
  // In some cases, centroids are "dropped out" of the above calculations
  // because no documents are assigned to them.  However, we want to keep
  // these because they may get documents assigned in future iterations.
  // To keep them, add in any items from the centroid matrix that are not
  // assigned a value during the above process
  dResult:=%dJoined%+JOIN(dCentroids,TABLE(%dJoined%,{id},id,LOCAL),LEFT.id=RIGHT.id,TRANSFORM(Docs.Types.DocumentMatrix,SELF:=LEFT;),LEFT ONLY,LOOKUP);
ENDMACRO;

END;