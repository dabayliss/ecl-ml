//-----------------------------------------------------------------------------
// Module used to cluster perform clustering on data in the NumericField
// format.  Includes functions for calculating distance using many different
// algorithms, determining centroid allegiance based on those distances, and
// performing K-Means calculations.
//-----------------------------------------------------------------------------
IMPORT * FROM $;
IMPORT Std.Str AS Str;
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

	// This is an alternative approach to generating a distance matrix - it allows for d02 to be bigger than a single machine memory
	// Of course the result is COUNT(d01)xCOUNT(d02) - so the files had better not be too big!

	SHARED c_model := ENUM ( Dense = 1, SJoins = 2, Background = 4 );
  EXPORT DFB := MODULE
	  // Each nested module is a 'control' interface for pairsB
		// Dense model - sparse vectors will be made dense - very simple handling of nulls - usually slow
		// Summary Joins - dimensions that are both non-null score directly; each combined score gets passed by the data from a join the summarizes either side
		// Background - a 'background' N^2 matrix is constructed from the summary joins - which is then merged with the dimension matched data
		// -- note Background REQUIRES that d02 fit in memory
		// 0 ==> score constructed only from co-populated dimensions and any EV1/2 stats computed
		// NAMING: A leading Q implies a 'quick' version of the result that probably shaves a corner or two
		//         A leading W implies a 'wide' version and is probably simple, unrestricted and painful
		//         No leading letter implies our 'best shot' at the 'correct' result
    EXPORT Default := MODULE,VIRTUAL
		  EXPORT UNSIGNED1 PModel := c_model.dense; // The process model for this distance metric
			EXPORT REAL8 EV1(DATASET(Types.NumericField) d) := 0; // An 'exotic' value which will be passed in at Comb time
			EXPORT REAL8 EV2(DATASET(Types.NumericField) d) := 0; // An 'exotic' value which will be passed in at Comb time
			EXPORT BOOLEAN JoinFilter(Types.t_FieldReal x,Types.t_FieldReal y,REAL8 ex1) := x<>0 OR y<>0; // If false - join value will not be computed
			EXPORT IV1(Types.t_FieldReal x,Types.t_FieldReal y) := x;
			EXPORT IV2(Types.t_FieldReal x,Types.t_FieldReal y) := y;
			EXPORT Types.t_FieldReal Comb1(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := 0; // The value1 - eventual result
			EXPORT Types.t_FieldReal Comb2(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := 0; // Scratchpad
			EXPORT Types.t_FieldReal Comb3(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := 0; // Scratchpad
// These can be though of as a 'turbo' or summary-join interface
// They will usually be used to prevent the need for dense computation
			EXPORT SummaryID1(DATASET(Types.NumericField) d) := d; // Used to create some form of summary by ID for dataset 1
			EXPORT SummaryID2(DATASET(Types.NumericField) d) := SummaryID1(d); // Used to create some form of summary by ID for dataset 2
			EXPORT Types.t_FieldReal Join11(Types.ClusterPair im,Types.NumericField ri) := 0; // join 1 result 1
			EXPORT Types.t_FieldReal Join12(Types.ClusterPair im,Types.NumericField ri) := 0;
			EXPORT Types.t_FieldReal Join13(Types.ClusterPair im,Types.NumericField ri) := 0;
			EXPORT Types.t_FieldReal Join21(Types.ClusterPair im,Types.NumericField ri) := 0;  // join 2 result 1
// This is the 'background' interface			
      EXPORT Types.t_FieldReal Background(Types.NumericField va1,Types.NumericField va2) := 0;// Compute background value from SI1/SI2 value
      EXPORT Types.t_FieldReal BackFront(Types.ClusterDistance Back,Types.ClusterPair Fro) := IF ( Fro.id>0, Fro.value01, Back.value );// Compute value given a background and a clusterpair <by default take front if possible>
	  END;

// These models compute a 'proper' Euclidean result but only for those vectors that have at least one dimension along
// which they both have a non-zero value. For very sparse vectors this will produce a result MUCH smaller than
// N^2 (and is correspondingly faster)		
    EXPORT QEuclideanSquared := MODULE(Default),VIRTUAL
		  EXPORT UNSIGNED1 PModel := c_model.SJoins;
			EXPORT SummaryID1(DATASET(Types.NumericField) d) := PROJECT(TABLE( d, { id, val := SUM(GROUP,value*value); }, id ),TRANSFORM(Types.NumericField,SELF.value:=LEFT.val,SELF.number:=0,SELF.id:=LEFT.id));
			EXPORT Comb1(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := SUM(D,(Value01-Value02)*(Value01-Value02));
			EXPORT Comb2(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := SUM(D,Value01*Value01);
			EXPORT Comb3(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := SUM(D,Value02*Value02); // sum of all the contributing rhs
			EXPORT Join11(Types.ClusterPair im,Types.NumericField ri) := im.value01 + ( ri.value-im.value02 ); // add in all of the lhs^2 that did not match
			EXPORT Join13(Types.ClusterPair im,Types.NumericField ri) := im.value03; // keep the rhs^2
			EXPORT Join21(Types.ClusterPair im,Types.NumericField ri) := im.value01 + ( ri.value-im.value03 ); // add in all of the rhs^2 that did not match
    END;
    EXPORT QEuclidean := MODULE(QEuclideanSquared)
			EXPORT Join21(Types.ClusterPair im,Types.NumericField ri) := SQRT(im.value01 + ( ri.value-im.value03 )); // add in all of the rhs^2 that did not match
    END;

// These models compute a proper Euclidean result (the full N^2) - they do require that D02 be able to fit in memory
// However given this is N^2 - if N does not fit in memory - you are probably dead anyway
    EXPORT EuclideanSquared := MODULE(QEuclideanSquared),VIRTUAL // QEuclidean with a background added
		  EXPORT UNSIGNED1 PModel := c_model.Background; // We avoid the SJoins through cleverness in BackFront
      EXPORT Types.t_FieldReal Background(Types.NumericField va1,Types.NumericField va2) := va1.value+va2.value;
      EXPORT Types.t_FieldReal BackFront(Types.ClusterDistance Back,Types.ClusterPair Fro) := IF ( Fro.id>0, Back.value+Fro.value01-Fro.value02-Fro.value03, Back.value );
    END;
    EXPORT Euclidean := MODULE(EuclideanSquared)
      EXPORT Types.t_FieldReal BackFront(Types.ClusterDistance Back,Types.ClusterPair Fro) := SQRT(IF ( Fro.id>0, Back.value+Fro.value01-Fro.value02-Fro.value03, Back.value ));
    END;
// These compute full Euclidean	the 'simple' way and have no obvious restrictions
// Expect to wait a while
    EXPORT WEuclideanSquared := MODULE(Default),VIRTUAL
			EXPORT IV1(Types.t_FieldReal x,Types.t_FieldReal y) := (x-y)*(x-y);
			EXPORT Comb1(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := SUM(D,Value01); 
    END;
    EXPORT WEuclidean := MODULE(WEuclideanSquared)
			EXPORT Comb1(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := SQRT( SUM(D,Value01) );
    END;
    EXPORT Manhattan := MODULE(Default),VIRTUAL
			EXPORT IV1(Types.t_FieldReal x,Types.t_FieldReal y) := ABS(x-y);
			EXPORT IV2(Types.t_FieldReal x,Types.t_FieldReal y) := 0;
			EXPORT Comb1(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := SUM(D,Value01);
    END;
		EXPORT Maximum := MODULE(Manhattan)
			EXPORT Comb1(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := MAX(D,Value01);
		END;
    EXPORT Cosine := MODULE(Default),VIRTUAL
			EXPORT Comb1(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := 1-SUM(D,Value01*Value02)/( SQRT(SUM(D,Value01*Value01))*SQRT(SUM(D,Value02*Value02)));
    END;
    EXPORT Tanimoto := MODULE(Default),VIRTUAL
			EXPORT Comb1(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := 1-SUM(D,Value01*Value02)/( SQRT(SUM(D,Value01*Value01))*SQRT(SUM(D,Value02*Value02))-SUM(D,Value01*Value02));
    END;
		// Now for some quick and dirty functions
		// This attempts to approximate the missing values - it will have far few intermediates if the matrices were sparse
		EXPORT MissingAppx := MODULE(Default),VIRTUAL
		  EXPORT UNSIGNED1 Pmodel := 0;
			EXPORT REAL8 EV1(DATASET(Types.NumericField) d) := AVE(d,value); // Average value
			EXPORT REAL8 EV2(DATASET(Types.NumericField) d) := MAX(TABLE(d,{UNSIGNED C := COUNT(GROUP)},id),C);
			EXPORT BOOLEAN JoinFilter(Types.t_FieldReal x,Types.t_FieldReal y,REAL8 ex1) := (x<>0 OR y<>0) AND ABS(x-y)<ex1; // Only produce record if closer
			EXPORT Types.t_FieldReal IV1(Types.t_FieldReal x,Types.t_FieldReal y) := ABS(x-y);
			EXPORT Types.t_FieldReal Comb1(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := SUM(d,value01) + (ev2-COUNT(d))*ev1;
		END;

		// Co-occurences - only counts number of fields with exact matches
		// For this metric missing values are 'infinity'
		EXPORT CoOccur := MODULE(Default),VIRTUAL
		  EXPORT UNSIGNED1 Pmodel := 0;
			EXPORT REAL8 EV1(DATASET(Types.NumericField) d) := MAX(d,number);
			EXPORT BOOLEAN JoinFilter(Types.t_FieldReal x,Types.t_FieldReal y,REAL8 ex1) := x<>0 AND x=y;
			EXPORT Types.t_FieldReal IV1(Types.t_FieldReal x,Types.t_FieldReal y) := 1;
			EXPORT Types.t_FieldReal Comb1(DATASET(Types.ClusterPair) d,REAL8 ev1,REAL8 ev2) := ev1 - COUNT(d);
		END;
	END;

// This is the 'distance computation engine'. It extremely configurable - see the 'Control' parameter
	EXPORT Distances(DATASET(Types.NumericField) d01,DATASET(Types.NumericField) d02,DFB.Default Control = DFB.Euclidean) := FUNCTION
		// If we are in dense model then fatten up the records; otherwise zeroes not needed
		df1 := IF( Control.Pmodel & c_model.dense > 0, Utils.Fat(d01), d01(value<>0) );
		df2 := IF( Control.Pmodel & c_model.dense > 0, Utils.Fat(d02), d02(value<>0) );
		// Construct the summary records used by SJoins and Background processing models
		si1 := Control.SummaryID1(df1); // Summaries of each document by ID
		si2 := Control.SummaryID2(df2); // May be used by any summary joins features
		// Construct the 'background' matrix from the summary matrix
		bck := JOIN(si1,si2,LEFT.id<>RIGHT.id,TRANSFORM(Types.ClusterDistance,SELF.ID := LEFT.id, SELF.ClusterId := RIGHT.Id, SELF.value := Control.BackGround(LEFT,RIGHT)),ALL);
		// Create up to two 'aggregate' numbers that the models may use
		ex1 := Control.EV1(d01); 
		ex2 := Control.EV2(d01);
		// This is the principle N^2 join (although some join filters can improve on that)
		Types.ClusterPair Take2(df1 le,df2 ri) := TRANSFORM
		  SELF.clusterid := le.id;
			SELF.id := ri.id;
			SELF.number := le.number;
			SELF.value01 := Control.IV1(le.value,ri.value);
			SELF.value02 := Control.IV2(le.value,ri.value);
		END;
		J := JOIN(df1,df2,LEFT.number=RIGHT.number AND LEFT.id<>RIGHT.id AND Control.JoinFilter(LEFT.value,RIGHT.value,ex1),Take2(LEFT,RIGHT),HASH); // numbers will be evenly distribute by definition
		// Take all of the values computed for each matching ID and combine them
		JG := GROUP(J,clusterid,id,ALL);
		Types.ClusterPair roll(Types.ClusterPair le, DATASET(Types.ClusterPair) gd) := TRANSFORM
		  SELF.Value01 := Control.Comb1(gd,ex1,ex2);
		  SELF.Value02 := Control.Comb2(gd,ex1,ex2); // These are really scratchpad
		  SELF.Value03 := Control.Comb3(gd,ex1,ex2);
		  SELF := le;
		END;
		rld := ROLLUP(JG,GROUP,roll(LEFT,ROWS(LEFT)));
		// In the SJoins processing model the si1/si2 data is now "passed to" the result - 01 first
		J1 := JOIN(rld,si1,LEFT.id=RIGHT.id,TRANSFORM(Types.ClusterPair,SELF.value01 := Control.Join11(LEFT,RIGHT),SELF.value02 := Control.Join12(LEFT,RIGHT),SELF.value03 := Control.Join13(LEFT,RIGHT), SELF := LEFT),LOOKUP);
		J2 := JOIN(J1,si2,LEFT.clusterid=RIGHT.id,TRANSFORM(Types.ClusterPair,SELF.value01 := Control.Join21(LEFT,RIGHT), SELF := LEFT),LOOKUP);
		// Select either the 'normal' or 'post joined' version of the scores
		Pro := IF ( Control.PModel & c_model.SJoins > 0, J2, rld );
		ProAsDist := PROJECT(Pro,TRANSFORM(Types.ClusterDistance,SELF.Value := LEFT.Value01, SELF := LEFT));
		// Now blend the scores that were computed with the background model
		Types.ClusterDistance blend(bck le,pro ri) := TRANSFORM
		  SELF.value := Control.BackFront(le,ri);
		  SELF := le;
		END;
		BF := JOIN(bck,pro,LEFT.ClusterID=RIGHT.ClusterID AND LEFT.id=RIGHT.id,blend(LEFT,RIGHT),LEFT OUTER);
		// Either select the background blended version - or slim the scores down to a cluster distance
		RETURN IF ( Control.PModel & c_model.Background > 0, BF, ProAsDist );
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

  EXPORT AggloN(DATASET(Types.NumericField) d,UNSIGNED4 N,DFB.Default Dist=DFB.Euclidean, c_Method cm=c_Method.min_dist):= MODULE
    Distance:=Distances(d,d,Dist)(id<>clusterid);
		dinit0 := DEDUP( d, ID, ALL );
		// To go around the loop this has to be a combined 'distance metric' / 'clusters so far' format
		ClusterRec := RECORD// Collect the full matrix of pair-pair distances
		  Types.t_RecordID ClusterId := dinit0.id;
			Types.t_RecordID Id := 0;
			Types.t_FieldReal value := 0;
			STRING Members := (STRING)dinit0.id;
		END;
		ConcatAll(DATASET(ClusterRec) s) := FUNCTION
			R := RECORD
			  STRING St;
			END;
			RETURN AGGREGATE(s,R,TRANSFORM(R,SELF.St := IF( RIGHT.St = '', LEFT.Members, RIGHT.St+' '+LEFT.Members)))[1].St;
		END;
		dinit1 := TABLE(dinit0,ClusterRec);
		DistAsClus := PROJECT( Distance, TRANSFORM(ClusterRec, SELF.Members:='', SELF := LEFT) );
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
			tojoin0 := JOIN(xposs,miny,LEFT.clusterid=RIGHT.clusterid AND LEFT.value=RIGHT.val,TRANSFORM(LEFT));
			// Now we have to avoid the transitive closure, no point in A->B if B->C
			// One option is to assert A->C; another is to break the A->B link
			tojoin := JOIN(tojoin0,tojoin0,LEFT.clusterid=RIGHT.id,TRANSFORM(LEFT),LEFT ONLY);
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
			// First we flag those that will be growing clusters with a 1
			J1 := JOIN(cl,tojoin,LEFT.Clusterid=RIGHT.Clusterid,TRANSFORM(ClusterRec,SELF.id := IF ( RIGHT.ClusterID<>0, 1, 0 ),SELF := LEFT),LEFT OUTER,KEEP(1));
			// Those that will be collapsing get the cluster number in their ID slot
			J2 := JOIN(J1(id=0),tojoin,LEFT.Clusterid=RIGHT.id,TRANSFORM(ClusterRec,SELF.id := RIGHT.ClusterId,SELF := LEFT),LEFT OUTER);
			// Those remaining inert will get a 0
			ClusterRec JoinCluster(J1 le,DATASET(ClusterRec) ri) := TRANSFORM
			  SELF.clusterid := le.clusterid;
				SELF.Members := '{'+le.Members+'}{'+ConcatAll(ri)+'}';
			END;
			J3 := DENORMALIZE(J1(id=1),J2(id<>0),LEFT.ClusterId=RIGHT.id,GROUP,JoinCluster(LEFT,ROWS(RIGHT)));
			RETURN IF(~EXISTS(CD),CL,J3+J2(id=0)+cd3);
		END;
	SHARED res := LOOP(dinit,N,Step(ROWS(LEFT)));
	EXPORT Dendrogram := TABLE(res(Members<>''),{ClusterId,Members});
	EXPORT Distances := TABLE(res(Members=''),{ClusterId,Id,Value});
		NoBrace(STRING S) := Str.CleanSpaces(Str.SubstituteIncluded(S,'{}',' '));
    De := TABLE(Dendrogram,{ClusterId,Ids := NoBrace(Members)});
		Types.ClusterDistance note(De le,UNSIGNED c) := TRANSFORM
		  SELF.ClusterId := le.ClusterId;
			SELF.Id := (UNSIGNED)Str.GetNthWord(le.Ids,c);
			SELF.value := 0; // Dendrogram does not return any cluster centroid distance measure
		END;
	EXPORT Clusters := NORMALIZE(De,Str.WordCount(LEFT.Ids),note(LEFT,COUNTER));
END;
	
END;