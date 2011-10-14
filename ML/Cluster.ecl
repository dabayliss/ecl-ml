IMPORT * FROM $;
EXPORT Cluster := MODULE

  EXPORT Matrix:=Types.NumericField;

  EXPORT MatrixPairs:=RECORD
    TYPEOF(Matrix.id)     id01;
    TYPEOF(Matrix.id)     id02;
    TYPEOF(Matrix.number) axis;
    TYPEOF(Matrix.value)  value01;
    TYPEOF(Matrix.value)  value02;
  END;
  
  EXPORT Distances:=RECORD
    TYPEOF(Matrix.id)     id01;
    TYPEOF(Matrix.number) id02;
    TYPEOF(Matrix.value)  distance;
  END;

  //---------------------------------------------------------------------------
  // Function to pair all the points in a primary matrix to all of the point
  // in a secondary matrix (presumably a centroid matrix). 
  //---------------------------------------------------------------------------
  EXPORT MatrixPairs fGetMatrixPairs(DATASET(Matrix) dMatrix01,DATASET(Matrix) dMatrix02):=FUNCTION
    d01Dist:=DISTRIBUTE(dMatrix01,id);
    d02Dist:=DISTRIBUTE(dMatrix02,id);

    // Get Unique IDs from both matrices and perform a full join so we have one
    // row for every possible combination of document id and centroid id.
    d01IDs:=TABLE(d01Dist,{TYPEOF(Matrix.id) id01:=id;},id,LOCAL);
    d02IDs:=TABLE(d02Dist,{TYPEOF(Matrix.id) id02:=id;},id,LOCAL);
    dPairs:=JOIN(d01IDs,d02IDs,LEFT.id01!=-RIGHT.id02,ALL,LOOKUP);

    // Join the dPairs table to each matrix separately.  This will re-format
    // them to the common MatrixPair format while also replicating the values
    // as many times as there are IDs in the other matrix.
    dWith01:=JOIN(DISTRIBUTE(dPairs,id01),d01Dist,LEFT.id01=RIGHT.id,TRANSFORM(MatrixPairs,SELF.axis:=RIGHT.number;SELF.value01:=RIGHT.value;SELF:=LEFT;SELF:=RIGHT;SELF:=[];),LOCAL);
    dWith02:=DISTRIBUTE(JOIN(DISTRIBUTE(dPairs,id02),d02Dist,LEFT.id02=RIGHT.id,TRANSFORM(MatrixPairs,SELF.axis:=RIGHT.number;SELF.value02:=RIGHT.value;SELF:=LEFT;SELF:=RIGHT;SELF:=[];),LOCAL),id01);

    // Combine the two joins above, and then roll where the id pair and
    // word_id are the same, collapsing same-axis values.
    dCombined:=SORT(dWith01+dWith02,id01,id02,axis,LOCAL);
    dRolled:=ROLLUP(dCombined,TRANSFORM(RECORDOF(dCombined),SELF.value01:=LEFT.value01+RIGHT.value01;SELF.value02:=LEFT.value02+RIGHT.value02;SELF:=LEFT;),id01,id02,axis,LOCAL);

    RETURN dRolled;
  END;

//-------------------------------------------------------------------------
  // Distance functions used to determine the distance between two matrix
  // points in a MatrixPairs dataset
  //-------------------------------------------------------------------------
  EXPORT DF := MODULE
    EXPORT Distances fDistancePrototype(DATASET(MatrixPairs) dPairs):=DATASET([],Distances);

    EXPORT Distances fEuclidean(DATASET(MatrixPairs) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id01;id02;TYPEOF(Distances.distance) diff_squared:=POWER(value01-value02,2);}),id01);
      dResults:=TABLE(dPrep,{id01;id02;TYPEOF(Distances.distance) distance:=SQRT(SUM(GROUP,diff_squared));},id01,id02,LOCAL);
      RETURN PROJECT(dResults,Distances);
    END;

    EXPORT Distances fEuclideanSquared(DATASET(MatrixPairs) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id01;id02;TYPEOF(Distances.distance) diff_squared:=POWER(value01-value02,2);}),id01);
      dResults:=TABLE(dPrep,{id01;id02;TYPEOF(Distances.distance) distance:=SUM(GROUP,diff_squared);},id01,id02,LOCAL);
      RETURN PROJECT(dResults,Distances);
    END;

    EXPORT Distances fManhattan(DATASET(MatrixPairs) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id01;id02;TYPEOF(Distances.distance) abs_diff:=ABS(value01-value02);}),id01);
      dResults:=TABLE(dPrep,{id01;id02;TYPEOF(Distances.distance) distance:=SUM(GROUP,abs_diff);},id01,id02,LOCAL);
      RETURN PROJECT(dResults,Distances);
    END;

    EXPORT Distances fCosine(DATASET(MatrixPairs) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id01;id02;TYPEOF(Distances.distance) product:=value01*value02;TYPEOF(Distances.distance) square01:=POWER(value01,2);TYPEOF(Distances.distance) square02:=POWER(value02,2);}),id01);
      dResults:=TABLE(dPrep,{id01;id02;TYPEOF(Distances.distance) distance:=1-(SUM(GROUP,product)/(SQRT(SUM(GROUP,square01))*SQRT(SUM(GROUP,square02))));},id01,id02,LOCAL);
      RETURN PROJECT(dResults,Distances);
    END;

    EXPORT Distances fTanimoto(DATASET(MatrixPairs) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id01;id02;TYPEOF(Distances.distance) product:=value01*value02;TYPEOF(Distances.distance) square01:=POWER(value01,2);TYPEOF(Distances.distance) square02:=POWER(value02,2);}),id01);
      dResults:=TABLE(dPrep,{id01;id02;TYPEOF(Distances.distance) distance:=1-(SUM(GROUP,product)/(SQRT(SUM(GROUP,square01))*SQRT(SUM(GROUP,square02))-SUM(GROUP,product)));},id01,id02,LOCAL);
      RETURN PROJECT(dResults,Distances);
    END;
  END;
  
  //---------------------------------------------------------------------------
  // fClosest takes a set of distances and returns a collapsed set containing
  // one row for each document ID contating the centroid to which it is closest
  //---------------------------------------------------------------------------
  EXPORT Distances fClosest(DATASET(Distances) dDistances):=DEDUP(SORT(DISTRIBUTE(dDistances,id01),id01,distance,LOCAL),id01,LOCAL);

  //---------------------------------------------------------------------------
  // fCalculateMeans takes a document matrix and a centroid matrix and re-
  // calculates the coordinates of the centroids using whichever distance
  // function the user desires.
  //---------------------------------------------------------------------------
  EXPORT Matrix CalculateMeans(DATASET(Matrix) dMatrix01,DATASET(Matrix) dMatrix02,DF.fDistancePrototype fFunction=DF.fEuclidean):=FUNCTION
    dPairs:=fGetMatrixPairs(dMatrix01,dMatrix02);
    dDistances:=fFunction(dPairs);
    dClosest:=fClosest(dDistances);

    dClusterCounts:=TABLE(dClosest,{id02;TYPEOF(Distances.distance) c:=(TYPEOF(Distances.distance))COUNT(GROUP);},id02);
    dClustered:=SORT(JOIN(DISTRIBUTE(dMatrix01,id),DISTRIBUTE(dClosest,id01),LEFT.id=RIGHT.id01,TRANSFORM(Matrix,SELF.id:=RIGHT.id02;SELF:=LEFT;SELF:=RIGHT;),LOCAL),RECORD,LOCAL);
    dRolled:=ROLLUP(dClustered,TRANSFORM(Matrix,SELF.value:=LEFT.value+RIGHT.value;SELF:=LEFT;),id,number,LOCAL);
    dJoined:=JOIN(dRolled,dClusterCounts,LEFT.id=RIGHT.id02,TRANSFORM(Matrix,SELF.value:=LEFT.value/RIGHT.c;SELF:=LEFT;),LOOKUP);

    RETURN dJoined+JOIN(dMatrix02,TABLE(dJoined,{id},id,LOCAL),LEFT.id=RIGHT.id,TRANSFORM(Matrix,SELF:=LEFT;),LEFT ONLY,LOOKUP);
  END;

  //---------------------------------------------------------------------------
  // Function to perform a user-specified number of iteration of the
  // CalculateMeans function.
  //---------------------------------------------------------------------------
  EXPORT Matrix IterateKMeans(DATASET(Matrix) dMatrix01,DATASET(Matrix) dMatrix02,UNSIGNED i,DF.fDistancePrototype fFunction=DF.fEuclidean):=FUNCTION
    dNewPositions:=LOOP(dMatrix02,i,CalculateMeans(dMatrix01,ROWS(LEFT),fFunction));
    RETURN dNewPositions;
  END;
END;