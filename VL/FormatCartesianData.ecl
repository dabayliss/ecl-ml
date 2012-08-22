//---------------------------------------------------------------------------
// Takes a table of cartesian data and strings it out into the standard
// CartesianData format that is used by cartesian-oriented charts.
// The input table is expected to have one column for x-axis labels, with all
// the other columns being y-axis numeric values related to those labels.
// The name of the column being used for x-axis labels should be specified in
// the second parameter.
//---------------------------------------------------------------------------
EXPORT FormatCartesianData(d,XAxis):=FUNCTIONMACRO
  LOADXML('<xml/>');
  #DECLARE(fieldnames) #SET(fieldnames,'')
  #DECLARE(x_axis) #SET(x_axis,'')
  #DECLARE(loopcount) #SET(loopcount,0)
  #EXPORTXML(fields,RECORDOF(d))
  #FOR(fields)
    #FOR(Field)
      #IF(REGEXFIND('^'+%'{@label}'%+'$',#TEXT(XAxis),NOCASE))
        #SET(x_axis,%'{@label}'%)
      #ELSE
        #APPEND(fieldnames,',\''+%'{@label}'%+'\'')
        #SET(loopcount,%loopcount%+1)
      #END
    #END
  #END
  RETURN DATASET([{'',%'x_axis'%,0}],VL.Types.CartesianData)+NORMALIZE(d,%loopcount%,TRANSFORM(VL.Types.CartesianData,SELF.series:=CHOOSE(COUNTER#EXPAND(%'fieldnames'%));SELF.segment:=(STRING)LEFT.#EXPAND(%'x_axis'%);SELF.val:=CHOOSE(COUNTER#EXPAND(REGEXREPLACE('\'',REGEXREPLACE(',\'',%'fieldnames'%,',LEFT.'),'')));));
ENDMACRO;

