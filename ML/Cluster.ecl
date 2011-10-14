//-----------------------------------------------------------------------------
// Module used to cluster perform clustering on data in the NumericField
// format.  Includes functions for calculating distance using many different
// algorithms, determining centroid allegiance based on those distances, and
// performing K-Means calculations.
//-----------------------------------------------------------------------------
IMPORT * FROM $;
EXPORT Cluster := MODULE
  //---------------------------------------------------------------------------
  // Function to pair all the points between two NumericField data sets. 
  //---------------------------------------------------------------------------
  EXPORT Types.CentroidPair Pairs(DATASET(Types.NumericField) d01,DATASET(Types.NumericField) d02):=FUNCTION
    d01Dist:=DISTRIBUTE(d01,id);
    d02Dist:=DISTRIBUTE(d02,id);

    // Get Unique IDs from both sets and perform a full join so we have one
    // row for every possible combination of two ids.
    d01IDs:=TABLE(d01Dist,{id;},id,LOCAL);
    d02IDs:=TABLE(d02Dist,{TYPEOF(Types.t_RecordID) centroid:=id;},id,LOCAL);
    dPairs:=JOIN(d01IDs,d02IDs,LEFT.id!=-RIGHT.centroid,ALL,LOOKUP);

    // Join the dPairs table to each data set separately.  This will re-format
    // them to the common Pairs format while also replicating the values
    // as many times as there are IDs in the other set.
    dWith01:=JOIN(DISTRIBUTE(dPairs,id),d01Dist,LEFT.id=RIGHT.id,TRANSFORM(Types.CentroidPair,SELF.value01:=RIGHT.value;SELF:=LEFT;SELF:=RIGHT;SELF:=[];),LOCAL);
    dWith02:=DISTRIBUTE(JOIN(DISTRIBUTE(dPairs,centroid),d02Dist,LEFT.centroid=RIGHT.id,TRANSFORM(Types.CentroidPair,SELF.value02:=RIGHT.value;SELF:=LEFT;SELF:=RIGHT;SELF:=[];),LOCAL),id);

    // Combine the two joins above, and then roll where the id pair and
    // field number are the same, collapsing same-field values.
    dCombined:=SORT(dWith01+dWith02,id,centroid,number,LOCAL);
    dRolled:=ROLLUP(dCombined,TRANSFORM(RECORDOF(dCombined),SELF.value01:=LEFT.value01+RIGHT.value01;SELF.value02:=LEFT.value02+RIGHT.value02;SELF:=LEFT;),id,centroid,number,LOCAL);

    RETURN dRolled;
  END;

  //-------------------------------------------------------------------------
  // Sub-moudle of pre-coded distance functions that can be used to calcluate
  // the distance for every pair of IDs in a table in the Pair layout.
  //-------------------------------------------------------------------------
  EXPORT DF := MODULE
    EXPORT Types.CentroidDistance DistancePrototype(DATASET(Types.CentroidPair) dPairs):=DATASET([],Types.CentroidDistance);

    EXPORT Types.CentroidDistance Euclidean(DATASET(Types.CentroidPair) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id;centroid;TYPEOF(Types.CentroidDistance.value) diff_squared:=POWER(value01-value02,2);}),id);
      dResults:=TABLE(dPrep,{id;centroid;TYPEOF(Types.CentroidDistance.value) value:=SQRT(SUM(GROUP,diff_squared));},id,centroid,LOCAL);
      RETURN PROJECT(dResults,Types.CentroidDistance);
    END;

    EXPORT Types.CentroidDistance EuclideanSquared(DATASET(Types.CentroidPair) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id;centroid;TYPEOF(Types.CentroidDistance.value) diff_squared:=POWER(value01-value02,2);}),id);
      dResults:=TABLE(dPrep,{id;centroid;TYPEOF(Types.CentroidDistance.value) value:=SUM(GROUP,diff_squared);},id,centroid,LOCAL);
      RETURN PROJECT(dResults,Types.CentroidDistance);
    END;

    EXPORT Types.CentroidDistance Manhattan(DATASET(Types.CentroidPair) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id;centroid;TYPEOF(Types.CentroidDistance.value) abs_diff:=ABS(value01-value02);}),id);
      dResults:=TABLE(dPrep,{id;centroid;TYPEOF(Types.CentroidDistance.value) value:=SUM(GROUP,abs_diff);},id,centroid,LOCAL);
      RETURN PROJECT(dResults,Types.CentroidDistance);
    END;

    EXPORT Types.CentroidDistance Cosine(DATASET(Types.CentroidPair) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id;centroid;TYPEOF(Types.CentroidDistance.value) product:=value01*value02;TYPEOF(Types.CentroidDistance.value) square01:=POWER(value01,2);TYPEOF(Types.CentroidDistance.value) square02:=POWER(value02,2);}),id);
      dResults:=TABLE(dPrep,{id;centroid;TYPEOF(Types.CentroidDistance.value) value:=1-(SUM(GROUP,product)/(SQRT(SUM(GROUP,square01))*SQRT(SUM(GROUP,square02))));},id,centroid,LOCAL);
      RETURN PROJECT(dResults,Types.CentroidDistance);
    END;

    EXPORT Types.CentroidDistance Tanimoto(DATASET(Types.CentroidPair) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id;centroid;TYPEOF(Types.CentroidDistance.value) product:=value01*value02;TYPEOF(Types.CentroidDistance.value) square01:=POWER(value01,2);TYPEOF(Types.CentroidDistance.value) square02:=POWER(value02,2);}),id);
      dResults:=TABLE(dPrep,{id;centroid;TYPEOF(Types.CentroidDistance.value) value:=1-(SUM(GROUP,product)/(SQRT(SUM(GROUP,square01))*SQRT(SUM(GROUP,square02))-SUM(GROUP,product)));},id,centroid,LOCAL);
      RETURN PROJECT(dResults,Types.CentroidDistance);
    END;
  END;
  
  //---------------------------------------------------------------------------
  // Closest takes a set of distances and returns a collapsed set containing
  // only the row for each id with the closest centroid
  //---------------------------------------------------------------------------
  EXPORT Types.CentroidDistance Closest(DATASET(Types.CentroidDistance) dDistances):=DEDUP(SORT(DISTRIBUTE(dDistances,id),id,value,LOCAL),id,LOCAL);

  //---------------------------------------------------------------------------
  // KMeans takes a data set and a centroid set, both in NumericField format,
  // and recalculates the coordinates for the centroids as the average of the
  // positions of any points from the data set to which the centroid is closest
  //---------------------------------------------------------------------------
  EXPORT Types.NumericField KMeans(DATASET(Types.NumericField) d01,DATASET(Types.NumericField) d02,DF.DistancePrototype fDist=DF.Euclidean):=FUNCTION
    dPairs:=Pairs(d01,d02);
    dDistances:=fDist(dPairs);
    dClosest:=Closest(dDistances);

    dClusterCounts:=TABLE(dClosest,{centroid;TYPEOF(Types.CentroidDistance.value) c:=(TYPEOF(Types.CentroidDistance.value))COUNT(GROUP);},centroid);
    dClustered:=SORT(JOIN(DISTRIBUTE(d01,id),DISTRIBUTE(dClosest,id),LEFT.id=RIGHT.id,TRANSFORM(Types.NumericField,SELF.id:=RIGHT.centroid;SELF:=LEFT;SELF:=RIGHT;),LOCAL),RECORD,LOCAL);
    dRolled:=ROLLUP(dClustered,TRANSFORM(Types.NumericField,SELF.value:=LEFT.value+RIGHT.value;SELF:=LEFT;),id,number,LOCAL);
    dJoined:=JOIN(dRolled,dClusterCounts,LEFT.id=RIGHT.centroid,TRANSFORM(Types.NumericField,SELF.value:=LEFT.value/RIGHT.c;SELF:=LEFT;),LOOKUP);

    RETURN dJoined+JOIN(d02,TABLE(dJoined,{id},id,LOCAL),LEFT.id=RIGHT.id,TRANSFORM(Types.NumericField,SELF:=LEFT;),LEFT ONLY,LOOKUP);
  END;

  //---------------------------------------------------------------------------
  // Function to perform a user-specified number of iterations of the
  // KMeans function.
  //---------------------------------------------------------------------------
  EXPORT Types.NumericField KMeansN(DATASET(Types.NumericField) d01,DATASET(Types.NumericField) d02,UNSIGNED i,DF.DistancePrototype fDist=DF.Euclidean):=FUNCTION
    dNewPositions:=LOOP(d02,i,KMeans(d01,ROWS(LEFT),fDist));
    RETURN dNewPositions;
  END;
END;