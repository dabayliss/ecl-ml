//---------------------------------------------------------------------------
// Function to swap the X and Y axes in a table of type ChartData
//---------------------------------------------------------------------------
IMPORT VL;
EXPORT SwapAxes(DATASET(VL.Types.CartesianData) d,STRING sNewXTitle):=FUNCTION
  RETURN PROJECT(d,TRANSFORM(RECORDOF(LEFT),SELF.segment:=IF(LEFT.series='',sNewXTitle,LEFT.series);SELF.series:=IF(LEFT.series='','',LEFT.segment);SELF:=LEFT;));
END;
