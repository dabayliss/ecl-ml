IMPORT Vl;
EXPORT D3(STRING sName,DATASET(VL.Types.ChartData) d,VL.Styles.Default p=VL.Styles.Default):=MODULE
  SHARED STRING sChartName:='D3CHART_'+sName;
  
  SHARED FormatChartData(DATASET(VL.Types.ChartData) d):=FUNCTION
    RETURN 'var points=['+ROLLUP(TABLE(d(series!=''),{STRING s:='['+d.segment+','+d.val+']';}),LEFT.s!=RIGHT.s,TRANSFORM(RECORDOF(LEFT),SELF.s:=LEFT.s+','+RIGHT.s))[1].s+'];';
  END;
  
  SHARED ChartOptions(VL.Styles.Default p):=FUNCTION
    sOpt:=''+
      IF(p.Height>0,'h='+(STRING)p.height+';','')+
      IF(p.Width>0,'w='+(STRING)p.width,'');
    RETURN IF(sOpt='','',sOpt);
  END;
  
  SHARED PageOptions(VL.Styles.Default p):=FUNCTION
    sOpt:=''+
      IF(p.Float=VL.Styles.FloatStyles.Left,',float:left',IF(p.Float=VL.Styles.FloatStyles.Right,',float:right',''))+
      IF(p.HTMLAdvanced<>'',','+p.HTMLAdvanced,'');
    RETURN IF(sOpt='','','div.'+sChartName+' {' + sOpt[2..] + '}');
  END;

  SHARED dData:=DATASET([{'DATA',FormatChartData(d)}],VL.Types.ChartInterface);
  SHARED dChartOptions:=DATASET([{'OPTIONS',ChartOptions(p)}],VL.Types.ChartInterface);
  SHARED dPageOptions:=DATASET([{'STYLES',PageOptions(p)}],VL.Types.ChartInterface);
  
  EXPORT Voronoi:=OUTPUT(dData+dChartOptions+dPageOptions+DATASET([{'CHARTCALL',VL.D3Templates.VoronoiTesselation(sChartName)}],VL.Types.ChartInterface),NAMED(sChartName));
END;