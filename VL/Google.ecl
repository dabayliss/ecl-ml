//---------------------------------------------------------------------------
// Module for processing data into the format expected by Google Charts, and
// then processing it through Google Charts
//---------------------------------------------------------------------------
IMPORT VL;
EXPORT Google(STRING sName,DATASET(VL.Types.ChartData) d,VL.Styles.Default p=VL.Styles.Default):=MODULE
  SHARED STRING sChartName:='GOOGLECHART_'+sName;
  SHARED FormatChartData(DATASET(VL.Types.ChartData) d,STRING sChartType='Std'):=FUNCTION
    #UNIQUENAME(i)
    bNumericX:=sChartType IN ['Scatter'];
    dSequenced:=PROJECT(d(series!=''),TRANSFORM({UNSIGNED %i%;RECORDOF(d);},SELF.%i%:=COUNTER;SELF:=LEFT;));
    dFieldNames:=SORT(TABLE(dSequenced,{STRING s:='{id:\''+TRIM(series)+'\',label:\''+TRIM(series)+'\',type:\'number\'}';UNSIGNED %i%:=MIN(%i%);},series),%i%);
    dFieldLine:=ROLLUP(dFieldNames,LEFT.s!=RIGHT.s,TRANSFORM(RECORDOF(dFieldNames),SELF.s:=LEFT.s+','+RIGHT.s;SELF:=LEFT;));
    sFieldNames:='var data=new google.visualization.DataTable({cols:[{id:\''+d(series='')[1].segment+'\',label:\''+d(series='')[1].segment+'\',type:'+IF(bNumericX,'\'number\'','\'string\'')+'},'+dFieldLine[1].s+'],';
    dFieldData:=SORT(TABLE(dSequenced,{dSequenced;STRING s:='{v:'+(STRING)val+'}';}),segment,%i%);
    dSegmentPrep01:=ROLLUP(dFieldData,LEFT.segment=RIGHT.segment,TRANSFORM(RECORDOF(dFieldData),SELF.s:=LEFT.s+','+RIGHT.s;SELF:=LEFT;));
    dSegmentPrep02:=PROJECT(dSegmentPrep01,TRANSFORM({STRING s;UNSIGNED %i%;},SELF.s:='{c:[{v:'+IF(bNumericX,'','\'')+TRIM(LEFT.segment)+IF(bNumericX,'','\'')+'},'+LEFT.s+']}';SELF:=LEFT;));
    dSegments:=ROLLUP(SORT(dSegmentPrep02,%i%),LEFT.s!=RIGHT.s,TRANSFORM(RECORDOF(dSegmentPrep02),SELF.s:=LEFT.s+','+RIGHT.s;SELF:=LEFT;));
    sWithSegments:=sFieldNames+'rows:['+dSegments[1].s+']});';
    RETURN sWithSegments;
  END;
  
  SHARED ChartOptions(VL.Styles.Default p):=FUNCTION
    sOpt:=''+
      IF(p.Title<>'',',title:"'+p.title+'"','')+
      IF(p.Height>0,',height:'+(STRING)p.height,'')+
      IF(p.Width>0,',width:'+(STRING)p.width,'')+
      IF(p.Is3D,',is3D:"TRUE"','')+
      IF(p.ShowLegend,'',',legend:{position:"none"}')+
      IF(p.BackgroundColor<>'',',backgroundColor:"'+p.BackgroundColor+'"','')+
      IF(p.ChartAdvanced<>'',','+p.ChartAdvanced,'');
    RETURN IF(sOpt='','','var options={'+sOpt[2..]+'};');
  END;
  
  SHARED PageOptions(VL.Styles.Default p):=FUNCTION
    sOpt:=''+
      IF(p.Float=VL.Styles.FloatStyles.Left,',float:left',IF(p.Float=VL.Styles.FloatStyles.Right,',float:right',''))+
      IF(p.HTMLAdvanced<>'',','+p.HTMLAdvanced,'');
    RETURN IF(sOpt='','','div.'+sChartName+' {' + sOpt[2..] + '}');
  END;
  
  // The four basic strings that are constructed as replacement strings in the
  // XSLT translator.
  SHARED dData(STRING sChartType='Std'):=DATASET([{'DATA',FormatChartData(d,sChartType)}],VL.Types.ChartInterface);
  SHARED dChart(STRING sChartType):=DATASET([{'CHARTCALL','var chart=new google.visualization.'+sChartType+'Chart(document.getElementById(\''+sChartName+'\'));chart.draw(data,options);'}],VL.Types.ChartInterface);
  SHARED dChartOptions:=DATASET([{'OPTIONS',ChartOptions(p)}],VL.Types.ChartInterface);
  SHARED dPageOptions:=DATASET([{'STYLES',PageOptions(p)}],VL.Types.ChartInterface);

  // The Graphs that are available for processing
  EXPORT Pie:=OUTPUT(dData()+dChartOptions+dPageOptions+dChart('Pie'),NAMED(sChartName));
  EXPORT Line:=OUTPUT(dData()+dChartOptions+dPageOptions+dChart('Line'),NAMED(sChartName));
  EXPORT Bar:=OUTPUT(dData()+dChartOptions+dPageOptions+dChart('Bar'),NAMED(sChartName));
  EXPORT Column:=OUTPUT(dData()+dChartOptions+dPageOptions+dChart('Column'),NAMED(sChartName));
  EXPORT Combo:=OUTPUT(dData()+dChartOptions+dPageOptions+dChart('Combo'),NAMED(sChartName));
  EXPORT Area:=OUTPUT(dData()+dChartOptions+dPageOptions+dChart('Area'),NAMED(sChartName));
  EXPORT Scatter:=OUTPUT(dData('Scatter')+dChartOptions+dPageOptions+dChart('Scatter'),NAMED(sChartName));
END;

