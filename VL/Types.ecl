EXPORT Types:=MODULE
  EXPORT ChartInterface:=RECORD
    STRING CHARTELEMENTTYPE;
    STRING s;
  END;

  EXPORT ChartData:=RECORD
    STRING series;
    STRING segment;
    REAL8 val;
  END;
  
END;