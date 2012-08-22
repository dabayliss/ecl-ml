EXPORT Types:=MODULE
  EXPORT ChartInterface:=RECORD
    STRING CHARTELEMENTTYPE;
    STRING s;
  END;

  EXPORT CartesianData:=RECORD
    STRING series;
    STRING segment;
    REAL8 val;
  END;
  
  EXPORT GraphLabels:=RECORD
    UNSIGNED id;
    STRING label;
  END;
  EXPORT GraphRelationships:=RECORD
    UNSIGNED id;
    UNSIGNED linkid;
    STRING linklabel:='';
    REAL weight:=0;
  END;
  
END;