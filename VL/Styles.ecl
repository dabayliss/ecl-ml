//---------------------------------------------------------------------------
// Container for the various styles that can be dictated by the user.
//---------------------------------------------------------------------------
EXPORT Styles:=MODULE
  EXPORT FloatStyles:=ENUM(None=1,Left=2,Right=4);
  EXPORT Default:=MODULE,VIRTUAL
    EXPORT STRING Title:='';
    EXPORT UNSIGNED2 Height:=400;
    EXPORT UNSIGNED2 Width:=600;
    EXPORT BOOLEAN Is3D:=FALSE;
    EXPORT BOOLEAN ShowLegend:=TRUE;
    EXPORT UNSIGNED1 Float:=FloatStyles.Left;
    EXPORT STRING BackgroundColor:='White';
    EXPORT STRING ChartAdvanced:='';
    EXPORT STRING HTMLAdvanced:='';
  END;
  
  EXPORT SetValue(m,i,v):=FUNCTIONMACRO
    n:=MODULE(m),VIRTUAL
      EXPORT #EXPAND(#TEXT(i)):=#EXPAND(#TEXT(v));
    END;
    RETURN n;
  ENDMACRO;
  
  EXPORT Small:=MODULE(Default),VIRTUAL
    EXPORT UNSIGNED2 Height:=100;
    EXPORT UNSIGNED2 Width:=150;
  END;
  
  EXPORT Large:=MODULE(Default),VIRTUAL
    EXPORT UNSIGNED2 Height:=600;
    EXPORT UNSIGNED2 Width:=900;
  END;
  
  EXPORT FloatRight:=MODULE(Default),VIRTUAL
    EXPORT Float:=FloatStyles.Right;
  END;
END;

