//---------------------------------------------------------------------------
// VL Default chart calls
//---------------------------------------------------------------------------
IMPORT VL;
EXPORT Chart(STRING sChartName,DATASET(VL.Types.ChartData) d,VL.Styles.Default p=VL.Styles.Default):=MODULE

  EXPORT Line:=VL.Google(sChartName,d,p).Line;
  EXPORT Bar:=VL.Google(sChartName,d,p).Bar;
  EXPORT Column:=VL.Google(sChartName,d,p).Column;
  EXPORT Area:=VL.Google(sChartName,d,p).Area;
  EXPORT Combo:=VL.Google(sChartName,d,p).Combo;
  EXPORT Pie:=VL.Google(sChartName,d,p).Pie;
  EXPORT Scatter:=VL.Google(sChartName,d,p).Scatter;
  EXPORT Geo:=VL.Google(sChartName,d,p).Geo;
  EXPORT Voronoi:=VL.D3(sChartName,d,p).Voronoi;

END;


