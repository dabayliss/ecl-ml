IMPORT Vl;
EXPORT D3(STRING sName,DATASET(VL.Types.ChartData) d,VL.Styles.Default p=VL.Styles.Default):=MODULE
  SHARED STRING sChartName:='D3CHART_'+sName;
  
  SHARED FormatData(DATASET(VL.Types.ChartData) d):=FUNCTION
    RETURN 'Hello World';
  END;
  
  SHARED ChartOptions(VL.Styles.Default p):=FUNCTION
    sOpt:=''+
      IF(p.Height>0,'h='+(STRING)p.height+';','')+
      IF(p.Width>0,'w='+(STRING)p.width,'');
    RETURN sOpt;
  END;
  
  SHARED PageOptions(VL.Styles.Default p):=FUNCTION
    sOpt:=''+
      IF(p.Float=VL.Styles.FloatStyles.Left,',float:left',IF(p.Float=VL.Styles.FloatStyles.Right,',float:right',''))+
      IF(p.HTMLAdvanced<>'',','+p.HTMLAdvanced,'');
    RETURN IF(sOpt='','','div.'+sChartName+' {' + sOpt[2..] + '}');
  END;

  SHARED dData:=DATASET([{'DATA',FormatData(d)}],VL.Types.ChartInterface);
  SHARED dChart(STRING sChartType):=DATASET([{'CHARTCALL','var chart=new google.visualization.'+sChartType+'Chart(document.getElementById(\''+sChartName+'\'));chart.draw(data,options);'}],VL.Types.ChartInterface);
  SHARED dChartOptions:=DATASET([{'OPTIONS',ChartOptions(p)}],VL.Types.ChartInterface);
  SHARED dPageOptions:=DATASET([{'STYLES',PageOptions}],VL.Types.ChartInterface);
  
  EXPORT Voronoi:=OUTPUT(dData,NAMED(sChartName));
END;