IMPORT ML;
IMPORT VL;

// Sample datasets
dCartesian:=DATASET([
  {'2004/05',165,938,522,998,450,614.6},
  {'2005/06',135,1120,599,1268,288,682},
  {'2006/07',157,1167,587,807,397,623},
  {'2007/08',139,1110,615,968,215,609.4},
  {'2008/09',136,691,629,1026,366,569.6}
],{STRING Month;UNSIGNED Bolivia;UNSIGNED Ecuador;UNSIGNED Madagascar;UNSIGNED Papua_Guinea;UNSIGNED Rwanda;REAL4 Average;});

dGrid:=DATASET([{1,3.25,7},{2,3.75,7.75},{3,3.5,2.5},{4,6.75,7},{5,5,5},{6,5.5,8},{7,6.5,2.5},{8,6.25,7.75},{9,4.5,8}],{UNSIGNED id;REAL x;REAL y;});

// Custom styles examples
PieStyle1:=Vl.Styles.SetValue(Vl.Styles.Default,is3D,true);
PieStyle:=Vl.Styles.SetValue(PieStyle1,title,'Coffeee Production by Country');

ComboStyle:=Vl.Styles.SetValue(Vl.Styles.Default,ChartAdvanced,'seriesType:"bars",series:{5:{type:"line"}}');

// Sample outputs
VL.Google('PieChart1',VL.Chart(TABLE(dCartesian,{month;bolivia;}),Month),PieStyle).Pie;
VL.Google('LineChart1',VL.Chart(dCartesian,Month)).Line;
VL.Google('BarChart1',VL.Chart(dCartesian,Month)).Bar;
VL.Google('ColumnChart1',VL.Chart(dCartesian,Month)).Column;
VL.Google('ComboChart1',VL.Chart(dCartesian,Month),ComboStyle).Combo;
VL.Google('AreaChart1',VL.Chart(dCartesian,Month)).Area;
VL.Google('ScatterChart1',VL.Chart(TABLE(dGrid,{x;y;}),x)).Scatter;



