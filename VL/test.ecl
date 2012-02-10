IMPORT VL;

dCartesian:=DATASET([
  {'2004/05',165,938,522,998,450,614.6},
  {'2005/06',135,1120,599,1268,288,682},
  {'2006/07',157,1167,587,807,397,623},
  {'2007/08',139,1110,615,968,215,609.4},
  {'2008/09',136,691,629,1026,366,569.6}
],{STRING Month;UNSIGNED Bolivia;UNSIGNED Ecuador;UNSIGNED Madagascar;UNSIGNED Papua_Guinea;UNSIGNED Rwanda;REAL4 Average;});

// VL.Chart(dCartesian,Month);

Google(DATASET(VL.Types.ChartData) d,VL.Styles.Default p=VL.Styles.Default):=MODULE
  SHARED FormatData(DATASET(VL.Types.ChartData) d):=FUNCTION
    #UNIQUENAME(i)
    dSequenced:=PROJECT(d(series!=''),TRANSFORM({UNSIGNED %i%;RECORDOF(d);},SELF.%i%:=COUNTER;SELF:=LEFT;));
    dFieldNames:=SORT(TABLE(dSequenced,{STRING s:='{id:\''+TRIM(series)+'\',label:\''+TRIM(series)+'\',type:\'number\'}';UNSIGNED %i%:=MIN(%i%);},series),%i%);
    dFieldLine:=ROLLUP(dFieldNames,LEFT.s!=RIGHT.s,TRANSFORM(RECORDOF(dFieldNames),SELF.s:=LEFT.s+','+RIGHT.s;SELF:=LEFT;));
    sFieldNames:='var data=new google.visualization.DataTable({cols:[{id:\''+d(series='')[1].segment+'\',label:\''+d(series='')[1].segment+'\',type:\'string\'},'+dFieldLine[1].s+'],';
    dFieldData:=SORT(TABLE(dSequenced,{dSequenced;STRING s:='{v:'+(STRING)val+'}';}),segment,%i%);
    dSegmentPrep01:=ROLLUP(dFieldData,LEFT.segment=RIGHT.segment,TRANSFORM(RECORDOF(dFieldData),SELF.s:=LEFT.s+','+RIGHT.s;SELF:=LEFT;));
    dSegmentPrep02:=PROJECT(dSegmentPrep01,TRANSFORM({STRING s;UNSIGNED %i%;},SELF.s:='{c:[{v:\''+TRIM(LEFT.segment)+'\'},'+LEFT.s+']}';SELF:=LEFT;));
    dSegments:=ROLLUP(SORT(dSegmentPrep02,%i%),LEFT.s!=RIGHT.s,TRANSFORM(RECORDOF(dSegmentPrep02),SELF.s:=LEFT.s+','+RIGHT.s;SELF:=LEFT;));
    sWithSegments:=sFieldNames+'rows:['+dSegments[1].s+']});';
    RETURN sWithSegments;
  END;
  
  SHARED FormatOptions(VL.Styles.Default p):=FUNCTION
    RETURN 'var options={'+'sOpt'+'};';
  END;
  
  SHARED dData:=DATASET([{'DATA',FormatData(d)}],VL.Types.ChartInterface);
  #UNIQUENAME(c)
  SHARED STRING sName(STRING sChartType):='GOOGLE_'+sChartType+%'c'%;
  SHARED dChart(STRING sChartType):=DATASET([{'CHARTCALL','var chart=new google.visualization.'+sChartType+'Chart(document.getElementById(\''+sName(sChartType)+'\'));chart.draw(data,options);'}],VL.Types.ChartInterface);
  SHARED dOptions:=DATASET([{'OPTIONS',FormatOptions(p)}],VL.Types.ChartInterface);

  EXPORT Line:=FUNCTION
    RETURN OUTPUT(dData+dOptions+dChart('Line'),NAMED(sName('Line')));
  END;
END;

Google(VL.Chart(dCartesian,Month),VL.Styles.Small).Line;


