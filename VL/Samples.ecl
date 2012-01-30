IMPORT ML;
IMPORT VL;

// Cartesian data
dCartesian:=DATASET([
  {'2004/05',165,938,522,998,450,614.6},
  {'2005/06',135,1120,599,1268,288,682},
  {'2006/07',157,1167,587,807,397,623},
  {'2007/08',139,1110,615,968,215,609.4},
  {'2008/09',136,691,629,1026,366,569.6}
],{STRING Month;UNSIGNED Bolivia;UNSIGNED Ecuador;UNSIGNED Madagascar;UNSIGNED Papua_Guinea;UNSIGNED Rwanda;REAL4 Average;});

dGrid:=DATASET([{1,3.25,7},{2,3.75,7.75},{3,3.5,2.5},{4,6.75,7},{5,5,5},{6,5.5,8},{7,6.5,2.5},{8,6.25,7.75},{9,4.5,8}],{UNSIGNED id;REAL x;REAL y;});

// Using standardized chart function
VL.GoogleStd(TABLE(dCartesian,{month;bolivia;}),'Pie','title:"Bolivian coffee production",is3D:true,width:600,height:400');
VL.GoogleStd(dCartesian,'Line','title:"Coffee Production",is3D:true,width:600,height:400');
VL.GoogleStd(dCartesian,'Bar','title:"Coffee Production",is3D:true,width:600,height:400');
VL.GoogleStd(dCartesian,'Column','title:"Coffee Production",is3D:true,width:600,height:400');
VL.GoogleStd(dCartesian,'Combo','title:"Coffee Production",is3D:true,width:600,height:400,seriesType:"bars",series:{5:{type:"line"}}');
VL.GoogleStd(dCartesian,'Area','title:"Coffee Production",is3D:true,width:600,height:400');
VL.GoogleStd(TABLE(dGrid,{x;y;}),'Scatter','title:"Comparison of Bolivia to Ecuador",is3D:true,width:600,height:400');

VL.D3Voronoi(TABLE(dGrid,{x;y;}),'w=600;h=400;');
