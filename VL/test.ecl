IMPORT VL;

dCartesian:=DATASET([
  {'2004/05',165,938,522,998,450,614.6},
  {'2005/06',135,1120,599,1268,288,682},
  {'2006/07',157,1167,587,807,397,623},
  {'2007/08',139,1110,615,968,215,609.4},
  {'2008/09',136,691,629,1026,366,569.6}
],{STRING Month;UNSIGNED Bolivia;UNSIGNED Ecuador;UNSIGNED Madagascar;UNSIGNED Papua_Guinea;UNSIGNED Rwanda;REAL4 Average;});

// VL.Chart(dCartesian,Month);

dChartData:=VL.Chart(dCartesian,Month);
MyStyle1:=VL.Styles.SetValue(Vl.Styles.Default,title,'Hello World');
MyStyle:=VL.Styles.SetValue(MyStyle1,BackgroundColor,'lightgrey');

VL.Google('LineChart1',dChartData).Line;
VL.Google('LineChart2',dChartData,VL.Styles.Small).Line;
VL.Google('LineChart3',dChartData,MyStyle).Line;


