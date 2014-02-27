IMPORT * FROM $;
IMPORT $.Mat;
IMPORT ML;

EXPORT Ensemble := MODULE
  SHARED t_node := INTEGER4;
  SHARED t_level := UNSIGNED2;
  SHARED t_Count:= Types.t_Count;
  SHARED t_Index:= INTEGER4;
  EXPORT NodeID := RECORD
    t_node node_id;
    t_level level;
  END;
  EXPORT NodeInstDiscrete := RECORD
    NodeID;
    Types.DiscreteField;
    Types.t_Discrete depend; // The dependant value
  END;
  EXPORT NodeInstContinuous := RECORD
    NodeID;
    Types.NumericField;
    Types.t_Discrete depend; // The dependant value
    BOOLEAN high_fork:=FALSE;
  END;
  EXPORT SplitF := RECORD		// data structure for splitting results
    NodeID;
    ML.Types.t_FieldNumber number; // The column used to split
    ML.Types.t_Discrete value; // The value for the column in question
    t_node new_node_id; // The new node that value goes to
  END;
  EXPORT SplitC := RECORD		// data structure for splitting results
    NodeID;
    ML.Types.t_FieldNumber number; // The column used to split
    ML.Types.t_FieldReal value; // The cutpoint value for the column in question
    INTEGER1 high_fork:=0;   // 0 = lower or equal than value, 1 greater than value
    t_node new_node_id; // The new node that value goes to
  END;
  EXPORT gSplitF := RECORD
    SplitF;
    t_count group_id;
  END;
  SHARED gNodeInstDisc := RECORD
    NodeInstDiscrete;
    t_count group_id;
  END;
  SHARED gNodeInstCont := RECORD
    NodeInstContinuous;
    t_count group_id;
  END;
  SHARED DepGroupedRec := RECORD(Types.DiscreteField)
    UNSIGNED group_id := 0;
    Types.t_RecordID new_id := 0;
  END;
  SHARED DepGroupedRec GroupDepRecords (Types.DiscreteField l, Sampling.idListGroupRec r) := TRANSFORM
    SELF.group_id 	:= r.gNum;
    SELF.new_id			:= r.id;
    SELF						:= l;
  END;
  SHARED NxKoutofM(t_Index N, Types.t_FieldNumber K, Types.t_FieldNumber M) := FUNCTION
    rndFeatRec:= RECORD
      t_count	      gNum   :=0;
      Types.t_FieldNumber number :=0;
      Types.t_FieldReal   rnd    :=0;
    END;
    seed:= DATASET([{0,0,0}], rndFeatRec);
    group_seed:= DISTRIBUTE(NORMALIZE(seed, N,TRANSFORM(rndFeatRec, SELF.gNum:= COUNTER)), gNum);
    allFields:= NORMALIZE(group_seed, M, TRANSFORM(rndFeatRec, SELF.number:= (COUNTER % M) +1, SELF.rnd:=RANDOM(), SELF:=LEFT),LOCAL);
    allSorted:= SORT(allFields, gNum, rnd, LOCAL);
    raw_set:= ENTH(allSorted, K, M, 1);
    RETURN TABLE(raw_set, {gNum, number});
  END;

  EXPORT gSplitInstances(DATASET(gSplitf) mod, DATASET(Types.DiscreteField) Indep) := FUNCTION
    splits:= mod(new_node_id <> 0);	// separate split or branches
    leafs := mod(new_node_id = 0);	// from final nodes
    join0 := JOIN(Indep, splits, LEFT.number = RIGHT.number AND LEFT.value = RIGHT.value, LOOKUP, MANY);
    sort0 := SORT(join0, group_id, id, level, number, node_id, new_node_id);
    group0:= GROUP(sort0, group_id, id);
    dedup0:= DEDUP(group0, LEFT.group_id = RIGHT.group_id AND LEFT.id = RIGHT.id AND LEFT.new_node_id != RIGHT.node_id, KEEP 1, LEFT);
    dedup1:= DEDUP(dedup0, LEFT.group_id = RIGHT.group_id AND LEFT.id = RIGHT.id AND LEFT.new_node_id = RIGHT.node_id, KEEP 1, RIGHT);
    RETURN dedup1;
  END;

// Function to split a set of nodes based on Feature Selection and Gini Impurity,
// the nodes received were generated sampling with replacement nTrees times.
// Note: it selects kFeatSel out of mTotFeats features for each sample, features must start at 1 and cannot exist a gap in the numeration.
  EXPORT RndFeatSelPartitionGIBased(DATASET(gNodeInstDisc) nodes, t_Count nTrees, t_Count kFeatSel, t_Count mTotFeats, t_Count p_level, REAL Purity=1.0):= FUNCTION
    this_set_all := DISTRIBUTE(nodes, HASH(group_id, node_id));
    node_base := MAX(this_set_all, node_id);           // Start allocating new node-ids from the highest previous
    featSet:= NxKoutofM(nTrees, kFeatSel, mTotFeats);  // generating list of features selected for each tree
    minFeats := TABLE(featSet, {gNum, minNumber := MIN(GROUP, number)}, gNum, FEW); // chose the min feature number from the sample
    this_minFeats:= JOIN(this_set_all, minFeats, LEFT.group_id = RIGHT.gNum AND LEFT.number= RIGHT.minNumber, LOOKUP);
    Purities := ML.Utils.Gini(this_minFeats, node_id, depend); // Compute the purities for each node
    PureEnough := Purities(1-Purity >= gini);
    // just need one match to create a leaf node, all similar instances will fall into the same leaf nodes
    pass_thru  := JOIN(PureEnough, this_set_all , LEFT.node_id=RIGHT.node_id, TRANSFORM(gNodeInstDisc, SELF.id:=0, SELF.number:=0, SELF.value:=0, SELF:=RIGHT), PARTITION RIGHT, KEEP(1));
    // splitting the instances that did not reach a leaf node
    this_set_out:= JOIN(this_set_all, PureEnough, LEFT.node_id=RIGHT.node_id, TRANSFORM(LEFT), LEFT ONLY, LOOKUP);
    this_set  := JOIN(this_set_out, featSet, LEFT.group_id = RIGHT.gNum AND LEFT.number= RIGHT.number, TRANSFORM(LEFT), LOOKUP);
    agg       := TABLE(this_set, {group_id, node_id, number, value, depend,Cnt := COUNT(GROUP)}, group_id, node_id, number, value, depend, LOCAL);
    aggc      := TABLE(agg, {group_id, node_id, number, value, TCnt := SUM(GROUP, Cnt)}, group_id, node_id, number, value, LOCAL);
    r := RECORD
      agg;
      REAL4 Prop; // Proportion pertaining to this dependant value
    END;
    prop := JOIN(agg, aggc, LEFT.group_id = RIGHT.group_id AND LEFT.node_id = RIGHT.node_id
            AND LEFT.number=RIGHT.number AND LEFT.value = RIGHT.value,
            TRANSFORM(r, SELF.Prop := LEFT.Cnt/RIGHT.Tcnt, SELF := LEFT), HASH);
    gini_per := TABLE(prop, {group_id, node_id, number, value, tcnt := SUM(GROUP,Cnt),val := SUM(GROUP,Prop*Prop)}, group_id, node_id, number, value, LOCAL);
    gini     := TABLE(gini_per, {group_id, node_id, number, gini_t := SUM(GROUP,tcnt*val)/SUM(GROUP,tcnt)}, group_id, node_id, number, LOCAL);
    splt     := DEDUP(SORT(gini, group_id, node_id, -gini_t, LOCAL), group_id, node_id, LOCAL);
    node_cand0 := JOIN(aggc, splt, LEFT.group_id = RIGHT.group_id AND LEFT.node_id = RIGHT.node_id AND LEFT.number = RIGHT.number, TRANSFORM(LEFT), LOOKUP, LOCAL);
    node_cand  := PROJECT(node_cand0, TRANSFORM({node_cand0, t_node new_nodeid}, SELF.new_nodeid := node_base + COUNTER, SELF := LEFT));
    // new split nodes found
    nc0      := PROJECT(node_cand, TRANSFORM(gNodeInstDisc, SELF.value := LEFT.new_nodeid, SELF.depend := LEFT.value, SELF.level := p_level, SELF := LEFT, SELF := []), LOCAL);
    // Assignig instances that didn't reach a leaf node to (new) node-ids (by joining to the sampled data)
    r1 := RECORD
      ML.Types.t_Recordid id;
      t_node nodeid;
    END;
    mapp := JOIN(this_set, node_cand, LEFT.group_id = RIGHT.group_id AND LEFT.node_id=RIGHT.node_id AND LEFT.number=RIGHT.number AND LEFT.value=RIGHT.value,
            TRANSFORM(r1, SELF.id := LEFT.id, SELF.nodeid:=RIGHT.new_nodeid ),LOOKUP, LOCAL);
    // Now use the mapping to actually reset all the points
    J := JOIN(this_set_out, mapp,LEFT.id=RIGHT.id,TRANSFORM(gNodeInstDisc, SELF.node_id:=RIGHT.nodeid, SELF.level:=LEFT.level+1, SELF := LEFT),LOCAL);
    RETURN pass_thru + nc0 + J;   // returning leaf nodes, new splits nodes and reassigned instances
  END;

// Function used in Random Forest classifier learning
// Note: it selects fsNum out of total number of features, they must start at 1 and cannot exist a gap in the numeration.
//       Gini Impurity's default parameters: Purity = 1.0 and maxLevel (Depth) = 32 (up to 126 max iterations)
// more info http://www.stat.berkeley.edu/~breiman/RandomForests/cc_home.htm#overview
  EXPORT SplitFeatureSampleGI(DATASET(Types.DiscreteField) Indep, DATASET(Types.DiscreteField) Dep, t_Index treeNum, t_Count fsNum, REAL Purity=1.0, t_level maxLevel=32) := FUNCTION
    N       := MAX(Dep, id);       // Number of Instances
    totFeat := COUNT(Indep(id=N)); // Number of Features
    depth   := MIN(126, maxLevel); // Max number of iterations when building trees (max 126 levels)
    // sampling with replacement the original dataset to generate treeNum Datasets
    grList:= ML.Sampling.GenerateNSampleList(treeNum, N); // the number of records will be N * treeNum
    groupDep:= JOIN(Dep, grList, LEFT.id = RIGHT.oldId, GroupDepRecords(LEFT, RIGHT)); // if grList were not too big we should use lookup
    // groupDep:= JOIN(Dep, grList, LEFT.id = RIGHT.oldId, GroupDepRecords(LEFT, RIGHT), MANY LOOKUP);
    ind0 := ML.Utils.FatD(Indep); // Ensure no sparsity in independents
    gNodeInstDisc init(Types.DiscreteField ind, DepGroupedRec depG) := TRANSFORM
      SELF.group_id := depG.group_id;
      SELF.node_id := depG.group_id;
      SELF.level := 1;
      SELF.depend := depG.value;	// Actually copies the dependant value to EVERY node - paying memory to avoid downstream cycles
      SELF.id := depG.new_id;
      SELF := ind;
    END;
    ind1 := JOIN(ind0, groupDep, LEFT.id = RIGHT.id, init(LEFT,RIGHT)); // If we were prepared to force DEP into memory then ,LOOKUP would go quicker
    // generating best feature_selection-gini_impurity splits, loopfilter level = COUNTER let pass only the nodes to be splitted for any current level
    res := LOOP(ind1, LEFT.level=COUNTER, COUNTER < depth , RndFeatSelPartitionGIBased(ROWS(LEFT), treeNum, fsNum, totFeat, COUNTER, Purity));
    // Turning LOOP results into splits and leaf nodes
    gSplitF toNewNode(gNodeInstDisc NodeInst) := TRANSFORM
      SELF.new_node_id  := IF(NodeInst.number>0, NodeInst.value, 0);
      SELF.number       := IF(NodeInst.number>0, NodeInst.number, 0);
      SELF.value        := NodeInst.depend;
      SELF:= NodeInst;
    END;
    new_nodes:= PROJECT(res(id=0), toNewNode(LEFT));    // node splits and leaf nodes
    // Taking care of instances (id>0) that reached maximum level and did not turn into a leaf yet
    mode_r := RECORD
      res.group_id;
      res.node_id;
      res.level;
      res.depend;
      Cnt := COUNT(GROUP);
    END;
    depCnt      := TABLE(res(id>0, number=1),mode_r, group_id, node_id, level, depend, FEW);
    depCntSort  := SORT(depCnt, group_id, node_id, cnt); // if more than one dependent value for node_id
    depCntDedup := DEDUP(depCntSort, group_id, node_id);     // the class value with more counts is selected
    maxlevel_leafs:= PROJECT(depCntDedup, TRANSFORM(gSplitF, SELF.number:=0, SELF.value:= LEFT.depend,
                                          SELF.new_node_id:=0, SELF:= LEFT));
    RETURN new_nodes + maxlevel_leafs;
  END;
END;