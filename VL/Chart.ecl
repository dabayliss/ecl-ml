EXPORT Chart(d,XAxis):=FUNCTIONMACRO
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
  RETURN DATASET([{'',%'x_axis'%,0}],VL.Types.ChartData)+NORMALIZE(d,%loopcount%,TRANSFORM(VL.Types.ChartData,SELF.series:=CHOOSE(COUNTER#EXPAND(%'fieldnames'%));SELF.segment:=LEFT.#EXPAND(%'x_axis'%);SELF.val:=CHOOSE(COUNTER#EXPAND(REGEXREPLACE('\'',REGEXREPLACE(',\'',%'fieldnames'%,',LEFT.'),'')));));
ENDMACRO;

