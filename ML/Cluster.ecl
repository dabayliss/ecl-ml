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
	// Assumes right hand side (d02) is fairly small (fits into memory)
  //---------------------------------------------------------------------------
  EXPORT Types.ClusterPair Pairs(DATASET(Types.NumericField) d01,DATASET(Types.NumericField) d02):=FUNCTION
    d01Dist:=DISTRIBUTE(d01,id);
    d02Dist:=DISTRIBUTE(d02,id);

    // Get Unique IDs from both sets and perform a full join so we have one
    // row for every possible combination of two ids.
    d01IDs:=TABLE(d01Dist,{id;},id,LOCAL);
    d02IDs:=TABLE(d02Dist,{TYPEOF(Types.t_RecordID) clusterid:=id;},id,LOCAL);
    dPairs:=JOIN(d01IDs,d02IDs,LEFT.id!=-RIGHT.clusterid,ALL,LOOKUP);

    // Join the dPairs table to each data set separately.  This will re-format
    // them to the common Pairs format while also replicating the values
    // as many times as there are IDs in the other set.
    dWith01:=JOIN(DISTRIBUTE(dPairs,id),d01Dist,LEFT.id=RIGHT.id,TRANSFORM(Types.ClusterPair,SELF.value01:=RIGHT.value;SELF:=LEFT;SELF:=RIGHT;SELF:=[];),LOCAL);
    dWith02:=DISTRIBUTE(JOIN(DISTRIBUTE(dPairs,clusterid),d02Dist,LEFT.clusterid=RIGHT.id,TRANSFORM(Types.ClusterPair,SELF.value02:=RIGHT.value;SELF:=LEFT;SELF:=RIGHT;SELF:=[];),LOCAL),id);

    // Combine the two joins above, and then roll where the id pair and
    // field number are the same, collapsing same-field values.
    dCombined:=SORT(dWith01+dWith02,id,clusterid,number,LOCAL);
    dRolled:=ROLLUP(dCombined,TRANSFORM(RECORDOF(dCombined),SELF.value01:=LEFT.value01+RIGHT.value01;SELF.value02:=LEFT.value02+RIGHT.value02;SELF:=LEFT;),id,clusterid,number,LOCAL);

    RETURN dRolled;
  END;

  //-------------------------------------------------------------------------
  // Sub-moudle of pre-coded distance functions that can be used to calcluate
  // the distance for every pair of IDs in a table in the Pair layout.
  //-------------------------------------------------------------------------
  EXPORT DF := MODULE
    EXPORT Types.ClusterDistance DistancePrototype(DATASET(Types.ClusterPair) dPairs):=DATASET([],Types.ClusterDistance);

    EXPORT Types.ClusterDistance Euclidean(DATASET(Types.ClusterPair) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id;clusterid;TYPEOF(Types.ClusterDistance.value) diff_squared:=POWER(value01-value02,2);}),id);
      dResults:=TABLE(dPrep,{id;clusterid;TYPEOF(Types.ClusterDistance.value) value:=SQRT(SUM(GROUP,diff_squared));},id,clusterid,LOCAL);
      RETURN PROJECT(dResults,Types.ClusterDistance);
    END;

    EXPORT Types.ClusterDistance EuclideanSquared(DATASET(Types.ClusterPair) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id;clusterid;TYPEOF(Types.ClusterDistance.value) diff_squared:=POWER(value01-value02,2);}),id);
      dResults:=TABLE(dPrep,{id;clusterid;TYPEOF(Types.ClusterDistance.value) value:=SUM(GROUP,diff_squared);},id,clusterid,LOCAL);
      RETURN PROJECT(dResults,Types.ClusterDistance);
    END;

    EXPORT Types.ClusterDistance Manhattan(DATASET(Types.ClusterPair) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id;clusterid;TYPEOF(Types.ClusterDistance.value) abs_diff:=ABS(value01-value02);}),id);
      dResults:=TABLE(dPrep,{id;clusterid;TYPEOF(Types.ClusterDistance.value) value:=SUM(GROUP,abs_diff);},id,clusterid,LOCAL);
      RETURN PROJECT(dResults,Types.ClusterDistance);
    END;

    EXPORT Types.ClusterDistance Cosine(DATASET(Types.ClusterPair) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id;clusterid;TYPEOF(Types.ClusterDistance.value) product:=value01*value02;TYPEOF(Types.ClusterDistance.value) square01:=POWER(value01,2);TYPEOF(Types.ClusterDistance.value) square02:=POWER(value02,2);}),id);
      dResults:=TABLE(dPrep,{id;clusterid;TYPEOF(Types.ClusterDistance.value) value:=1-(SUM(GROUP,product)/(SQRT(SUM(GROUP,square01))*SQRT(SUM(GROUP,square02))));},id,clusterid,LOCAL);
      RETURN PROJECT(dResults,Types.ClusterDistance);
    END;

    EXPORT Types.ClusterDistance Tanimoto(DATASET(Types.ClusterPair) dPairs):=FUNCTION
      dPrep:=DISTRIBUTE(TABLE(dPairs,{id;clusterid;TYPEOF(Types.ClusterDistance.value) product:=value01*value02;TYPEOF(Types.ClusterDistance.value) square01:=POWER(value01,2);TYPEOF(Types.ClusterDistance.value) square02:=POWER(value02,2);}),id);
      dResults:=TABLE(dPrep,{id;clusterid;TYPEOF(Types.ClusterDistance.value) value:=1-(SUM(GROUP,product)/(SQRT(SUM(GROUP,square01))*SQRT(SUM(GROUP,square02))-SUM(GROUP,product)));},id,clusterid,LOCAL);
      RETURN PROJECT(dResults,Types.ClusterDistance);
    END;
  END;
  
  //---------------------------------------------------------------------------
  // Closest takes a set of distances and returns a collapsed set containing
  // only the row for each id with the closest centroid
  //---------------------------------------------------------------------------
  EXPORT Types.ClusterDistance Closest(DATASET(Types.ClusterDistance) dDistances):=DEDUP(SORT(DISTRIBUTE(dDistances,id),id,value,LOCAL),id,LOCAL);

  //---------------------------------------------------------------------------
  // KMeans takes a data set and a centroid set, both in NumericField format,
  // and recalculates the coordinates for the centroids as the average of the
  // positions of any points from the data set to which the centroid is closest
  //---------------------------------------------------------------------------
  EXPORT Types.NumericField KMeans(DATASET(Types.NumericField) d01,DATASET(Types.NumericField) d02,DF.DistancePrototype fDist=DF.Euclidean):=FUNCTION
    dPairs:=Pairs(d01,d02);
    dDistances:=fDist(dPairs);
    dClosest:=Closest(dDistances);

    dClusterCounts:=TABLE(dClosest,{clusterid;TYPEOF(Types.ClusterDistance.value) c:=(TYPEOF(Types.ClusterDistance.value))COUNT(GROUP);},clusterid);
    dClustered:=SORT(JOIN(DISTRIBUTE(d01,id),DISTRIBUTE(dClosest,id),LEFT.id=RIGHT.id,TRANSFORM(Types.NumericField,SELF.id:=RIGHT.clusterid;SELF:=LEFT;SELF:=RIGHT;),LOCAL),RECORD,LOCAL);
    dRolled:=ROLLUP(dClustered,TRANSFORM(Types.NumericField,SELF.value:=LEFT.value+RIGHT.value;SELF:=LEFT;),id,number,LOCAL);
    dJoined:=JOIN(dRolled,dClusterCounts,LEFT.id=RIGHT.clusterid,TRANSFORM(Types.NumericField,SELF.value:=LEFT.value/RIGHT.c;SELF:=LEFT;),LOOKUP);

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

// When combining clusters how to compute the distances of the new clusters to each other
// Min-dist - minimum of the components
// Max-dist - maximum of the components
// ave-dist - average of the components
  EXPORT c_Method := ENUM( min_dist,max_dist,ave_dist );

  // Agglomerative (or Hierarchical clustering) - attempts to weld the clusters together bottom up
	// N is the number of steps to take
  EXPORT AggloN(DATASET(Types.NumericField) d,UNSIGNED4 N,DF.DistancePrototype fDist=DF.Euclidean, c_Method cm=c_Method.min_dist):=FUNCTION
// Collect the full matrix of pair-pair distances
    Distances:=fDist(Pairs(d,d))(id<>clusterid);
		dinit0 := DEDUP( d, ID, ALL );
		// To go around the loop this has to be a combined 'distance metric' / 'clusters so far' format
		ClusterRec := RECORD
		  Types.t_RecordID ClusterId := dinit0.id;
			Types.t_RecordID Id := 0;
			Types.t_FieldReal value := 0;
			STRING Members := (STRING)dinit0.id;
		END;
		dinit1 := TABLE(dinit0,ClusterRec);
		DistAsClus := PROJECT( Distances, TRANSFORM(ClusterRec, SELF.Members:='', SELF := LEFT) );
		Dinit := dinit1+DistAsClus;
		Step(DATASET(ClusterRec) cd00) := FUNCTION
		  cd := cd00(Members='');
			cl := cd00(Members<>'');
		  // Find the best value for each id
			minx := TABLE(cd,{id,val := MIN(GROUP,value)},id);
			// Find the best value for each cluster
			miny := TABLE(cd,{clusterid,val := MIN(GROUP,value)},clusterid);
			// Find those entries that are best - only pick clusterid<id (so entries only found once) 
			xposs := JOIN(cd(clusterid<id),minx,LEFT.id=RIGHT.id AND LEFT.value=RIGHT.val,TRANSFORM(LEFT));
			// Make sure the other side is just as happy
			tojoin := JOIN(xposs,miny,LEFT.clusterid=RIGHT.clusterid AND LEFT.value=RIGHT.val);
			// Now we need to mutilate the distance table to reflect the new reality
			// We do this first by 'duping' the elements
			cd0 := JOIN(cd,tojoin,LEFT.id=RIGHT.id,TRANSFORM(ClusterRec,SELF.id:=IF(RIGHT.id<>0,RIGHT.clusterid,LEFT.id),SELF:=LEFT),LOOKUP,LEFT OUTER)(id<>clusterid);
			cd1 := JOIN(cd0,tojoin,LEFT.clusterid=RIGHT.id,TRANSFORM(ClusterRec,SELF.clusterid:=IF(RIGHT.id<>0,RIGHT.clusterid,LEFT.clusterid),SELF:=LEFT),LOOKUP,LEFT OUTER)(id<>clusterid);
			r1 := RECORD
			  cd1.id;
				cd1.clusterid;
				REAL8 MinV := MIN(GROUP,cd1.value);
				REAL8 MaxV := MAX(GROUP,cd1.value);
				REAL8 AveV := AVE(GROUP,cd1.value);
			END;
			cd2 := TABLE(cd1,r1,id,clusterid);
			cd3 := PROJECT(cd2,TRANSFORM(ClusterRec,SELF.Members:='',SELF.value := CASE( cm,c_Method.min_dist => LEFT.MinV, c_Method.max_dist => LEFT.MaxV, LEFT.AveV ), SELF := LEFT ));
			// Now perform the actual clustering
			J := JOIN(cl,tojoin,LEFT.Clusterid=RIGHT.id,TRANSFORM(ClusterRec,SELF.id := RIGHT.ClusterId,SELF := LEFT),LEFT OUTER);
			J_Collapsing := J(id<>0);
			J_NotC := J(id=0);
			J_Untouch := JOIN(J_NotC,tojoin,LEFT.ClusterId=RIGHT.ClusterID,TRANSFORM(LEFT),LEFT ONLY);
			ClusterRec JoinCluster(J_Collapsing le,cl ri) := TRANSFORM
			  SELF.clusterid := MIN(le.clusterid,ri.clusterid);
				SELF.Members := '{'+ri.Members+'}{'+le.Members+'}';
			END;
			J2 := JOIN(J_Collapsing(id<>0),cl,LEFT.id=RIGHT.Clusterid,JoinCluster(LEFT,RIGHT));
			RETURN IF(~EXISTS(CD),CL,J_Untouch+J2+cd3);
		END;
		RETURN TABLE(LOOP(dinit,N,Step(ROWS(LEFT)))(Members<>''),{ClusterId,Members});
	END;
	
END;