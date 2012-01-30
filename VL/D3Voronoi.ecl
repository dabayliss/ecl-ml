//---------------------------------------------------------------------------
// Macro takes a matrix of x and y values and plots them into a Voronoi
// Tesselation.
// The dataset is assumed to be a 2-column table of numeric data.
//---------------------------------------------------------------------------
IMPORT VL;
EXPORT D3Voronoi(d,sOpt='\'\''):=FUNCTIONMACRO
  sData:=VL.ToArray(d);
  
  #UNIQUENAME(c)
  sChartName:='D3Voronoi'+%'c'%;
  dData:=DATASET([{'DATA','var points='+sData+';'}],VL.Types.ChartInterface);
  dWithOptions:=dData+DATASET([{'OPTIONS',sOpt}],VL.Types.ChartInterface);
  dWithChartCall:=dWithOptions+DATASET([{'CHARTCALL',VL.D3Templates.VoronoiTesselation(sChartName)}],VL.Types.ChartInterface);
  RETURN OUTPUT(dWithChartCall,NAMED(sChartName));
ENDMACRO;