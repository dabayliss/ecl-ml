IMPORT * FROM $;

seed := DATASET([{0,0,0}], Types.Element);

Types.Element addNodeNum(Types.Element L, unsigned4 c) := transform
    SELF.x := c;
		SELF.y := c;
		SELF.value := 1.0;
  END;

one_per_node := distribute(normalize(seed, CLUSTERSIZE, addNodeNum(LEFT, COUNTER)), x);

EXPORT Identity(integer4 dimension) := FUNCTION

Types.Element fillRow(Types.Element L, unsigned4 c) := TRANSFORM
SELF.x := l.x+CLUSTERSIZE*(c-1);
SELF.y := l.y+CLUSTERSIZE*(c-1);
SELF.value := 1.0;
END;
m := NORMALIZE(one_per_node, ROUNDUP(dimension/CLUSTERSIZE), fillRow(LEFT,COUNTER))(x <= dimension);
RETURN m;
END;