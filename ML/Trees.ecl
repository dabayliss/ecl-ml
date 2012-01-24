IMPORT ML,ML.Mat;
EXPORT Trees := MODULE
  SHARED t_node := INTEGER4; // Assumes a maximum of 32 levels presently
	SHARED t_level := INTEGER1; // Would allow up to 2^256 levels
  EXPORT Node := RECORD
    t_node node_id; // The node-id for a given point
    t_level level; // The level for a given point
    ML.Types.NumericField;
  END;
  
  
/*
	The NodeIds within a KdTree follow a natural pattern - all the node-ids will have the same number of bits - corresponding to the
  depth of the tree+1. The left-most will always be 1. Moving from left to right a 0 always implies taking the 'low' decision at a node
  and a 1 corresponds to taking a 'high'. Thus an ID of 6 = 110 has been split twice; and this group is in the high then low group
  The Splits show the number and value used to split at each point
*/
  EXPORT KdTree(DATASET(ML.Types.NumericField) f,t_level Depth=10,t_level MedianDepth=0) := MODULE
	// Cannot presently support median computation on more than 32K nodes at once due to use of FieldAggregate library
	MedDepth := MIN(MedianDepth,15);
	  // Each iteration attempts to work with the next level down the tree; resolving multiple sub-trees at once
		// The reason is to ensure that the full cluster is busy all the time
		// It is assumed that all of the data-nodes are distributed by HASH(id) throughout
  Split(DATASET(Node) nodes, t_level p_level) := FUNCTION
    working_nodes:=nodes(level=p_level);
		// For every node_id this computes the maximum and minimum extent of the space
		spans := TABLE(working_nodes,{ minv := MIN(GROUP,value); maxv := MAX(GROUP,value); node_id,number }, node_id,number, MERGE);
		// Now find the split points - that is the number with the largest span for each node_id
		sp := DEDUP( SORT( DISTRIBUTE(spans, HASH(node_id)),node_id,minv-maxv,LOCAL), node_id, LOCAL );
		// Here we compute the split point based upon the mean of the range
		splits_mean := PROJECT( sp, TRANSFORM(Node,SELF.Id := 0, SELF.level := p_level, SELF.value := (LEFT.maxv+LEFT.minv)/2,SELF := LEFT) );
		// Here we create split points based upon the median
		// this gives even split points - but it adds an NLgN process into the loop ...
		// Method currently uses field aggregates - which requires the node-id to fit into 16 bits
		into_med := JOIN(working_nodes,sp,LEFT.node_id=RIGHT.node_id AND LEFT.number=RIGHT.number,TRANSFORM(ML.Types.NumericField,SELF.Number := LEFT.node_id,SELF := LEFT),LOOKUP);
		// Transform into splits format - but oops - field is missing
		s_median := PROJECT( ML.FieldAggregates(into_med).medians, TRANSFORM(Node, SELF.Id := 0, SELF.level := p_level, SELF.node_id:=LEFT.number, SELF.value := LEFT.median, SELF.number := 0));
		splits_median := JOIN(s_median,sp,LEFT.node_id=RIGHT.node_id,TRANSFORM(Node,SELF.number := RIGHT.number,SELF := LEFT),FEW);
		splits := IF ( p_level < MedDepth, splits_median, splits_mean );
		// based upon the split points we now partition the data - note the split information is assumed to fit inside RAM
		// First we perform the split on field to get record_id/node_id pairs
		r := RECORD
		  ML.Types.t_RecordId id;
			t_node node_id;
		END;
		r NoteNI(working_nodes le, splits ri) := TRANSFORM
		  SELF.node_id := (le.node_id << 1) + IF(le.value<ri.value,0,1);
		  SELF.id := le.id;
		END;
		// The ,LOOKUP means that the result will be distributed by ID still
		ndata := JOIN(working_nodes,splits,LEFT.node_id = RIGHT.node_id AND LEFT.number=RIGHT.number,NoteNI(LEFT,RIGHT),LOOKUP);
		// The we apply those record_id/node_id pairs back to the original data / we can use local because of the ,LOOKUP above
		patched := JOIN(working_nodes,ndata,LEFT.id=RIGHT.id,TRANSFORM(Node,SELF.node_id := RIGHT.node_id, SELF.level := LEFT.level+1,SELF := LEFT),LOCAL);
		RETURN nodes(level<p_level)+splits+patched;
  END;


	  d1 := DISTRIBUTE(PROJECT(ML.Utils.Fat(f,0),TRANSFORM(Node,SELF.Level := 1, SELF.node_id := 1,SELF := LEFT)),HASH(id));
		SHARED Res := LOOP(D1,Depth,Split(ROWS(LEFT),COUNTER));
		EXPORT Splits := Res(id=0); // The split points used to partition each node id
		EXPORT Partitioned := Res(id<>0); // The training data - all partitioned
		EXPORT Counts := TABLE(Partitioned(number=1),{ node_id, Cnt := COUNT(GROUP) }, node_id, FEW); // Number of training elements in each partition
		EXPORT CountMean := AVE(Counts,Cnt);
		EXPORT CountVariance := VARIANCE(Counts,Cnt);
		EXPORT Extents := TABLE(Partitioned,{ node_id, number, MinV := MIN(GROUP,Value), MaxV := MAX(GROUP,Value) }, node_id, number, FEW);
	END;

/*
	The decision tree is designed to split a dataset such that the dependant variables are concentrated by value inside the nodes
	Put a different way; we are aiming for a node to have one value for the dependant variable
  It is possible to construct a decision tree with continuous data; for now we are tackling the discrete case
	Assume raw-data distributed by record-id
  The tree building has two independent termination conditions - the tree Depth and the required purity of a given node
  The purity is measured using the Gini co-efficient
*/
  EXPORT Decision(DATASET(ML.Types.DiscreteField) ind,DATASET(ML.Types.DiscreteField) dep,t_level Depth=10,REAL Purity=1.0) := MODULE

  SHARED wNode := RECORD
    t_node node_id; // The node-id for a given point
    t_level level; // The level for a given point
		ML.Types.t_Discrete depend; // Actually copies the dependant value to EVERY node - paying memory to avoid downstream cycles
    ML.Types.DiscreteField;
  END;
	ind0 := ML.Utils.FatD(ind); // Ensure no sparsity in independants
	wNode init(ind0 le,dep ri) := TRANSFORM
	  SELF.node_id := 1;
		SELF.level := 1;
		SELF.depend := ri.value;
	  SELF := le;
	END;
	ind1 := JOIN(ind,dep,LEFT.id = RIGHT.id,init(LEFT,RIGHT)); // If we were prepared to force DEP into memory then ,LOOKUP would go quicker

	Split(DATASET(wNode) nodes, t_level p_level) := FUNCTION
		this_set0 := nodes(level = p_level); // Only process those 'undecided' nodes
		Purities := ML.Utils.Gini(this_set0(number=1),node_id,depend); // Compute the purities for each node
		// At this level these nodes are pure enough
		PureEnough := Purities(1-Purity >= gini);
		// Remove the 'pure enough' from the working set
		this_set := JOIN(this_set0,PureEnough,LEFT.node_id=RIGHT.node_id,TRANSFORM(LEFT),LEFT ONLY,LOOKUP);
		// Make sure the 'pure enough' get through
		pass_thru := JOIN(this_set0,PureEnough,LEFT.node_id=RIGHT.node_id,TRANSFORM(LEFT),LOOKUP);

		// Implementation note: it is very tempting to want to distribute by node_id - however at any given level there are only 2^level nodes
		// so if you want to distribute on a large number of clusters; you cannot pre-distribute.

		// Implementation node II: this code could be made rather cleaner by re-using the Utils.Gini routine; HOWEVER
		// it would require an extra join and potentially an extra data scan. For now it is assumed that 'code is cheap'
		
		// In a single step compute the counts for each dependant value for each field for each node
		// Note: the MERGE is to allow for high numbers of dimensions, high cardinalities in the discretes or both
		// for low dimension, low cardinality cases a ,FEW would be significantly quicker
		agg := TABLE(this_set,{node_id,number,value,depend,Cnt := COUNT(GROUP)},node_id,number,value,depend,MERGE);

		// Now to turn those counts into proportions; need the counts independant of depend
		// Could re-count from this_set; but using agg as it is (probably) significantly smaller
		aggc := TABLE(agg,{node_id,number,value,TCnt := SUM(GROUP,Cnt)},node_id,number,value,MERGE);
		r := RECORD
		  agg;
			REAL4 Prop; // Proportion pertaining to this dependant value
		END;
		// Now on each row we have the proportion of the node that is that dependant value
		prop := JOIN(agg,aggc,LEFT.node_id=RIGHT.node_id AND LEFT.number=RIGHT.number AND LEFT.value = RIGHT.value,
		             TRANSFORM(r, SELF.Prop := LEFT.Cnt/RIGHT.Tcnt, SELF := LEFT),HASH);
		// Compute 1-gini coefficient for each node for each field for each value
		gini_per := TABLE(prop,{node_id,number,value,tcnt := SUM(GROUP,Cnt),val := SUM(GROUP,Prop*Prop)},node_id,number,value);
		// The gini coeff for each value is then formed into a weighted average to give the impurity based upon the field
		gini := TABLE(gini_per,{node_id,number,gini_t := SUM(GROUP,tcnt*val)/SUM(GROUP,tcnt)},node_id,number,FEW);
		// We can now work out which nodes to split and based upon which column
		splt := DEDUP( SORT( DISTRIBUTE( gini,HASH(node_id) ), node_id, -gini_t, LOCAL ), node_id, LOCAL );
		// We now need to allocate node-ids for the nodes we are about to create; because we cannot control the size of the discrete
		// fields we cannot do this via bit-shifting (as in the kd-trees); rather we will have to enumerate them an allocate sequentially
		// The 'aggc' really has nothing to do with the below; it is just a convenient list of node_id/number/value that happens to be 
		// laying around - so we using it rather than hitting a bigger dataset
		node_cand0 := JOIN(aggc,splt,LEFT.node_id=RIGHT.node_id AND LEFT.number=RIGHT.number,TRANSFORM(LEFT),LOOKUP);
	  node_base := MAX(aggc,node_id); // Start allocating new node-ids from the highest previous
		// Allocate the new node-ids
		node_cand := PROJECT(node_cand0,TRANSFORM({node_cand0, t_node new_nodeid},SELF.new_nodeid := node_base+COUNTER, SELF := LEFT));
		// Construct a fake wNode to pass out splitting information
		nc0 := PROJECT(node_cand,TRANSFORM(wNode,SELF.value := LEFT.new_nodeid,SELF.depend := LEFT.value,SELF.level := p_level,SELF := LEFT,SELF := []));
		// Construct a list of record-ids to (new) node-ids (by joining to the real data)
		r1 := RECORD
		  ML.Types.t_Recordid id;
			t_node nodeid;
		END;
		// Mapp will be distributed by id because this_set is - and a ,LOOKUP join does not destroy order
		mapp := JOIN(this_set,node_cand,LEFT.node_id=RIGHT.node_id AND LEFT.number=RIGHT.number AND LEFT.value=RIGHT.value, TRANSFORM(r1,SELF.id := LEFT.id,SELF.nodeid:=RIGHT.new_nodeid),LOOKUP);
		// Now use the mapping to actually reset all the points		
		J := JOIN(this_set,mapp,LEFT.id=RIGHT.id,TRANSFORM(wNode,SELF.node_id:=RIGHT.nodeid,SELF.level:=LEFT.level+1,SELF := LEFT),LOCAL);
		RETURN J+nc0+nodes(level < p_level)+pass_thru;
	END;
		SHARED res := LOOP(ind1,Depth,Split(ROWS(LEFT),COUNTER));
		SplitF := RECORD
		  t_node node_id;
			t_level level;
			ML.Types.t_FieldNumber number; // The column used to split
			ML.Types.t_Discrete value;
			t_node new_node_id;
		END;
		EXPORT Splits := PROJECT(Res(id=0),TRANSFORM(SplitF,SELF.new_node_id := LEFT.value, SELF.value := LEFT.depend, SELF := LEFT)); // The split points used to partition each node id
		SHARED nsplits := res(id<>0);
		EXPORT Partitioned := PROJECT(nsplits,Node); // The training data - all partitioned
		// number=1 pulled simply to get 1 record per record-id <note: did a .FatD earlier>
		EXPORT Counts := TABLE(Partitioned(number=1),{ node_id, Lvl := MAX(GROUP,level), Cnt := COUNT(GROUP) }, node_id, FEW); // Number of training elements in each partition
		EXPORT Purities := ML.Utils.Gini(nsplits(number=1),node_id,depend);
		EXPORT CountMean := AVE(Counts,Cnt);
		EXPORT CountVariance := VARIANCE(Counts,Cnt);
	END;


END;
