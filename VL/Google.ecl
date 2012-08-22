//---------------------------------------------------------------------------
// Module for processing data into the format expected by Google Charts, and
// then processing it through Google Charts
//---------------------------------------------------------------------------
IMPORT VL;
EXPORT Google:=MODULE
  // Function takes data formatted in the standard cartesian format and
  // constructs the string that will be plugged into the template
  SHARED STRING FormatChartData(DATASET(VL.Types.CartesianData) d,STRING sChartType='Std'):=FUNCTION
    #UNIQUENAME(i)
    bNumericX:=sChartType IN ['Scatter'];
    dSequenced:=PROJECT(d(series!=''),TRANSFORM({UNSIGNED %i%;RECORDOF(d);},SELF.%i%:=COUNTER;SELF:=LEFT;));
    dFieldNames:=SORT(TABLE(dSequenced,{STRING s:='{id:\''+TRIM(series)+'\',label:\''+TRIM(series)+'\',type:\'number\'}';UNSIGNED %i%:=MIN(%i%);},series),%i%);
    dFieldLine:=ROLLUP(dFieldNames,LEFT.s!=RIGHT.s,TRANSFORM(RECORDOF(dFieldNames),SELF.s:=LEFT.s+','+RIGHT.s;SELF:=LEFT;));
    sFieldNames:='{cols:[{id:\''+d(series='')[1].segment+'\',label:\''+d(series='')[1].segment+'\',type:'+IF(bNumericX,'\'number\'','\'string\'')+'},'+dFieldLine[1].s+'],';
    dFieldData:=SORT(TABLE(dSequenced,{dSequenced;STRING s:='{v:'+(STRING)val+'}';}),segment,%i%);
    dSegmentPrep01:=ROLLUP(dFieldData,LEFT.segment=RIGHT.segment,TRANSFORM(RECORDOF(dFieldData),SELF.s:=LEFT.s+','+RIGHT.s;SELF:=LEFT;));
    dSegmentPrep02:=PROJECT(dSegmentPrep01,TRANSFORM({STRING s;UNSIGNED %i%;},SELF.s:='{c:[{v:'+IF(bNumericX,'','\'')+TRIM(LEFT.segment)+IF(bNumericX,'','\'')+'},'+LEFT.s+']}';SELF:=LEFT;));
    dSegments:=ROLLUP(SORT(dSegmentPrep02,%i%),LEFT.s!=RIGHT.s,TRANSFORM(RECORDOF(dSegmentPrep02),SELF.s:=LEFT.s+','+RIGHT.s;SELF:=LEFT;));
    sWithSegments:=sFieldNames+'rows:['+dSegments[1].s+']}';
    RETURN sWithSegments;
  END;

  // Takes any options specified in the Styles virtual module that relate to
  // chart-specific options and adds them to a string that will be enveloped
  // by the template.
  SHARED STRING ChartOptions(VL.Styles.Default p):=FUNCTION
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
  
  // Same as above, but for page-specific options (float, etc).
  SHARED STRING PageOptions(STRING sChartName,VL.Styles.Default p):=FUNCTION
    sOpt:=''+
      IF(p.Float=VL.Styles.FloatStyles.Left,',float:left',IF(p.Float=VL.Styles.FloatStyles.Right,',float:right',''))+
      IF(p.HTMLAdvanced<>'',','+p.HTMLAdvanced,'');
    RETURN IF(sOpt='','','div.'+sChartName+' {' + sOpt[2..] + '}');
  END;

  // Function takes the variable elements and wraps them into the default
  // template used to produce Google Charts
  SHARED STRING DefaultTemplate(STRING sChartType,STRING sChartName,DATASET(VL.Types.CartesianData) d,VL.Styles.Default s):=''+
    '<html><head><META http-equiv="Content-Type" content="text/html; charset=UTF-8">'+
    '<title>Google Chart Visualization</title>'+
    '<style type="text/css">'+PageOptions(sChartName,s)+'</style>'+
    '<script type="text/javascript" src="http://www.google.com/jsapi"></script>'+
    '<script type="text/javascript">'+
    'google.load(\'visualization\', \'1.0\', {packages: [\'corechart\', \'geochart\', \'annotatedtimeline\', \'table\', \'motionchart\', \'ImageSparkLine\']});'+
    'google.setOnLoadCallback(draw'+sChartName+');'+
    'function draw'+sChartName+'(){'+
    'var data=new google.visualization.DataTable('+FormatChartData(d,IF(sChartType='ScatterChart','Scatter','Std'))+');'+ChartOptions(s)+
    'var chart=new google.visualization.'+sChartType+'(document.getElementById(\''+sChartName+'\'));chart.draw(data,options);'+
    '}</script></head><body>'+
    '<div id="'+sChartName+'" class="'+sChartName+'"></div>'+
    '</body></html>';

  // The primary function call for Cartesian charts using Google Charts
  EXPORT Cartesian(STRING sChartType,STRING sChartName,DATASET(VL.Types.CartesianData) d,VL.Styles.Default s=VL.Styles.Default):=FUNCTION
    RETURN OUTPUT(DATASET([{'CHARTCODE',DefaultTemplate(sChartType,sChartName,d,s)}],VL.Types.ChartInterface),NAMED('CHART_'+sChartName));
  END;

END;


