IMPORT ML,ML.Mat;
EXPORT Trees := MODULE
  SHARED t_node := INTEGER4; // Assumes a maximum of 32 levels presently
	SHARED t_level := INTEGER1; // Would allow up to 2^256 levels
  EXPORT KdNode := RECORD
    t_node node_id; // The node-id for a given point
    t_level level; // The level for a given point
    ML.Types.NumericField;
  END;
  
	  // Each iteration attempts to work with the next level down the tree; resolving multiple sub-trees at once
		// The reason is to ensure that the full cluster is busy all the time
		// It is assumed that all of the data-nodes are distributed by HASH(id) throughout
  Split(DATASET(KdNode) nodes, t_level p_level) := FUNCTION
    working_nodes:=nodes(level=p_level);
		// For every node_id this computes the maximum and minimum extent of the space
		spans := TABLE(working_nodes,{ minv := MIN(GROUP,value); maxv := MAX(GROUP,value); node_id,number }, node_id,number, MERGE);
		// Now find the split points - that is the number with the largest span for each node_id
		sp := DEDUP( SORT( DISTRIBUTE(spans, HASH(node_id)),node_id,minv-maxv,LOCAL), node_id, LOCAL );
		// Here we compute the split point based upon the mean of the range
		// An alternative would be to use the node-id/field information to compute a median value; this would guarantee even splits
		// but it adds an NLgN process into the loop ...
		splits := PROJECT( sp, TRANSFORM(KdNode,SELF.Id := 0, SELF.level := p_level, SELF.value := (LEFT.maxv+LEFT.minv)/2,SELF := LEFT) );
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
		// The ,FEW means that the result will be distributed by ID still
		ndata := JOIN(working_nodes,splits,LEFT.node_id = RIGHT.node_id AND LEFT.number=RIGHT.number,NoteNI(LEFT,RIGHT),LOOKUP);
		// The we apply those record_id/node_id pairs back to the original data / we can use local because of the ,LOOKUP above
		patched := JOIN(working_nodes,ndata,LEFT.id=RIGHT.id,TRANSFORM(KdNode,SELF.node_id := RIGHT.node_id, SELF.level := LEFT.level+1,SELF := LEFT),LOCAL);
		RETURN nodes(level<p_level)+splits+patched;
  END;
  
/*
	The NodeIds within a KdTree follow a natural pattern - all the node-ids will have the same number of bits - corresponding to the
  depth of the tree+1. The left-most will always be 1. Moving from left to right a 0 always implies taking the 'low' decision at a node
  and a 1 corresponds to taking a 'high'. Thus an ID of 6 = 110 has been split twice; and this group is in the high then low group
  The Splits show the number and value used to split at each point
*/
  EXPORT KdTree(DATASET(ML.Types.NumericField) f,t_level Depth=10) := MODULE
	  d1 := DISTRIBUTE(PROJECT(ML.Utils.Fat(f,0),TRANSFORM(KdNode,SELF.Level := 1, SELF.node_id := 1,SELF := LEFT)),HASH(id));
		SHARED Res := LOOP(D1,Depth,Split(ROWS(LEFT),COUNTER));
		EXPORT Splits := Res(id=0); // The split points used to partition each node id
		EXPORT Partitioned := Res(id<>0); // The training data - all partitioned
		EXPORT Counts := TABLE(Partitioned(number=1),{ node_id, Cnt := COUNT(GROUP) }, node_id, FEW); // Number of training elements in each partition
		EXPORT Extents := TABLE(Partitioned,{ node_id, number, MinV := MIN(GROUP,Value), MaxV := MAX(GROUP,Value) }, node_id, number, FEW);
	END;
END;
