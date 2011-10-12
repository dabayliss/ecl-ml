IMPORT ML.Docs AS Docs;

EXPORT Distance:=MODULE

//---------------------------------------------------------------------------
// Plug-in distance functions.  These will take the table that contains the
// combination of every document to every centroid (OUTER JOINed on the y
// value) and calculate the distance between them.
// The functions refer to this combined table using the reserved word
// "PAIREDTABLE", and to the results with the reserved word "OUTPUTTABLE".
// The paired table has the following structure, and is distributed on the 
// document's x value:
//   RECORD
//    TYPEOF(Docs.Types.DocumentMatrix.x) doc_id;
//    TYPEOF(Docs.Types.DocumentMatrix.x) cen_id;
//    TYPEOF(Docs.Types.DocumentMatrix.y) axis;
//    TYPEOF(Docs.Types.DocumentMatrix.value) doc_value;
//    TYPEOF(Docs.Types.DocumentMatrix.value) cen_value;
//   END;
//---------------------------------------------------------------------------

// DF_EUCLIDEAN: The simple Pythagorean calcluation.  Square root of the sum
// of the squares
EXPORT STRING DF_EUCLIDEAN:=''+
'  #UNIQUENAME(d01)'+
'  %d01%:=TABLE(PAIREDTABLE,{doc_id;cen_id;TYPEOF(Docs.Types.DocumentMatrix.value) diff_squared:=POWER(doc_value-cen_value,2);});'+
'  OUTPUTTABLE:=TABLE(%d01%,{doc_id;cen_id;TYPEOF(Docs.Types.DocumentMatrix.value) distance:=SQRT(SUM(GROUP,diff_squared));},doc_id,cen_id,LOCAL);';

// DF_EUCLIDEAN_SQUARED: same as DF_EUCLIDEAN, but without the square root
EXPORT STRING DF_EUCLIDEAN_SQUARED:=''+
'  #UNIQUENAME(d01)'+
'  %d01%:=TABLE(PAIREDTABLE,{doc_id;cen_id;TYPEOF(Docs.Types.DocumentMatrix.value) diff_squared:=POWER(doc_value-cen_value,2);});'+
'  OUTPUTTABLE:=TABLE(%d01%,{doc_id;cen_id;TYPEOF(Docs.Types.DocumentMatrix.value) distance:=SUM(GROUP,diff_squared);},doc_id,cen_id,LOCAL);';

// DF_MANHATTAN: Sum of the absolute value of the delta on each axis
EXPORT STRING DF_MANHATTAN:=''+
'  #UNIQUENAME(d01)'+
'  %d01%:=TABLE(PAIREDTABLE,{doc_id;cen_id;TYPEOF(Docs.Types.DocumentMatrix.value) abs_diff:=ABS(doc_value-cen_value);});'+
'  OUTPUTTABLE:=TABLE(%d01%,{doc_id;cen_id;TYPEOF(Docs.Types.DocumentMatrix.value) distance:=SUM(GROUP,abs_diff);},doc_id,cen_id,LOCAL);';

// DF_COSINE: Sum of the products of all of the axes divided by product of
// the square root of the sum of all of the squares of the document values
// and the square root of all of the squares of the centroid values.  Then
// subtract that from 1.
EXPORT STRING DF_COSINE:=''+
'  #UNIQUENAME(d01)'+
'  %d01%:=TABLE(PAIREDTABLE,{doc_id;cen_id;TYPEOF(Docs.Types.DocumentMatrix.value) product:=doc_value*cen_value;TYPEOF(Docs.Types.DocumentMatrix.value) doc_squared:=POWER(doc_value,2);TYPEOF(Docs.Types.DocumentMatrix.value) cen_squared:=POWER(cen_value,2);});'+
'  OUTPUTTABLE:=TABLE(%d01%,{doc_id;cen_id;TYPEOF(Docs.Types.DocumentMatrix.value) distance:=1-(SUM(GROUP,product)/(SQRT(SUM(GROUP,doc_squared))*SQRT(SUM(GROUP,cen_squared))));},doc_id,cen_id,LOCAL);';

// DF_TANIMOTO: Same as DF_COSINE except that we subtract the sum of the
// product on each axis from the denominator
EXPORT STRING DF_TANIMOTO:=''+
'  #UNIQUENAME(d01)'+
'  %d01%:=TABLE(PAIREDTABLE,{doc_id;cen_id;TYPEOF(Docs.Types.DocumentMatrix.value) product:=doc_value*cen_value;TYPEOF(Docs.Types.DocumentMatrix.value) doc_squared:=POWER(doc_value,2);TYPEOF(Docs.Types.DocumentMatrix.value) cen_squared:=POWER(cen_value,2);});'+
'  OUTPUTTABLE:=TABLE(%d01%,{doc_id;cen_id;TYPEOF(Docs.Types.DocumentMatrix.value) distance:=1-(SUM(GROUP,product)/(SQRT(SUM(GROUP,doc_squared))*SQRT(SUM(GROUP,cen_squared))-SUM(GROUP,product)));},doc_id,cen_id,LOCAL);';

//---------------------------------------------------------------------------
// Given a document matrix and a centroid matrix, this macro calculates the
// distance between every pairing between the two matrices.
// User passes the following parameters:
//  dDocuments       : Dataset containing the document matrix
//  dCentroids       : Dataset contianing the centroid matrix
//  sDistanceFunction: STRING variable containing the function that will be
//                     used to calculate the distance.
//  dOut             : The name of the output dataset of distances
//  bClosestOnly     : [OPTIONAL] If TRUE, the output will be DEDUPed so that
//                     there will be one row for each document showing the
//                     centroid to which it is closest.  Otherwise all
//                     distances will be displayed
//---------------------------------------------------------------------------
EXPORT macCalculateDistance(dDocuments,dCentroids,sDistanceFunction,dOut,bClosestOnly=FALSE):=MACRO
  #UNIQUENAME(lWords)
  %lWords%:={Docs.Types.DocumentMatrix AND NOT [id];BOOLEAN isdoc;};

  // For a clean full join on the x values, with an outer join on the y values,
  // we first roll up every y value as child datasets on for both the document
  // and centroid matrices.
  #UNIQUENAME(dDocPrep)
  %dDocPrep%:=TABLE(SORT(DISTRIBUTE(dDocuments,id),id,word_id,LOCAL),{TYPEOF(Docs.Types.DocumentMatrix.id) doc_id:=id;DATASET(%lWords%) words:=DATASET([{word_id,value,TRUE}],%lWords%);});
  #UNIQUENAME(dDocs)
  %dDocs%:=ROLLUP(%dDocPrep%,TRANSFORM(RECORDOF(%dDocPrep%),SELF.words:=LEFT.words+RIGHT.words;SELF:=LEFT;),doc_id,LOCAL);
  #UNIQUENAME(dCenPrep)
  %dCenPrep%:=TABLE(SORT(DISTRIBUTE(dCentroids,id),id,word_id,LOCAL),{TYPEOF(Docs.Types.DocumentMatrix.id) cen_id:=id;DATASET(%lWords%) words:=DATASET([{word_id,value,FALSE}],%lWords%);});
  #UNIQUENAME(dCens)
  %dCens%:=ROLLUP(%dCenPrep%,TRANSFORM(RECORDOF(%dCenPrep%),SELF.words:=LEFT.words+RIGHT.words;SELF:=LEFT;),cen_id,LOCAL);

  // Now that we have one row for each x value, full join every row in the
  // document matrix to every row in the centroid matrix
  #UNIQUENAME(dJoined)
  %dJoined%:=JOIN(%dDocs%,%dCens%,LEFT.doc_id!=-RIGHT.cen_id,TRANSFORM({TYPEOF(%dDocs%.doc_id) doc_id;RECORDOF(%dCens%);},SELF.words:=SORT(LEFT.words+RIGHT.words,word_id);SELF:=LEFT;SELF:=RIGHT;),ALL,LOOKUP);

  // Normalize out the resulting join so that we have a flat file again,
  // parsing out the document and centroid y values
  #UNIQUENAME(lPaired)
  %lPaired%:=RECORD
    TYPEOF(Docs.Types.DocumentMatrix.id) doc_id;
    TYPEOF(Docs.Types.DocumentMatrix.id) cen_id;
    TYPEOF(Docs.Types.DocumentMatrix.word_id) word_id;
    TYPEOF(Docs.Types.DocumentMatrix.value) doc_value;
    TYPEOF(Docs.Types.DocumentMatrix.value) cen_value;
  END;
  #UNIQUENAME(dNormed)
  %dNormed%:=NORMALIZE(%dJoined%,LEFT.words,TRANSFORM(%lPaired%,SELF.doc_value:=IF(RIGHT.isdoc,RIGHT.value,0);SELF.cen_value:=IF(RIGHT.isdoc,0,RIGHT.value);SELF.word_id:=RIGHT.word_id;SELF:=LEFT;));
  #UNIQUENAME(dPaired)
  %dPaired%:=ROLLUP(%dNormed%,TRANSFORM(%lPaired%,SELF.doc_value:=LEFT.doc_value+RIGHT.doc_value;SELF.cen_value:=LEFT.cen_value+RIGHT.cen_value;SELF:=LEFT;),doc_id,cen_id,word_id,LOCAL);
  
  // Perform the distance calculation on for every document/centroid pair in
  // the fully paired table.
  #UNIQUENAME(dDistances)
  #EXPAND(REGEXREPLACE('OUTPUTTABLE',REGEXREPLACE('PAIREDTABLE',sDistanceFunction,%'dPaired'%),%'dDistances'%));
  
  // If the user specified closest-only, dedup the results before outputting.
  dOut:=#IF(bClosestOnly) DEDUP(SORT(%dDistances%,doc_id,distance,LOCAL),doc_id,LOCAL) #ELSE %dDistances% #END;
ENDMACRO;

END;
