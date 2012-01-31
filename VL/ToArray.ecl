//---------------------------------------------------------------------------
// Macro to convert a rectangular matrix into a simple Javascript Array of
// numbers.  Return value is STRING.
//---------------------------------------------------------------------------
EXPORT ToArray(dIn):=FUNCTIONMACRO
 LOADXML('<xml/>');
  #DECLARE(cols) #SET(cols,'\'[\'')
  #EXPORTXML(fields,RECORDOF(dIn))
  #FOR(fields)
    #FOR(Field)
      #IF(REGEXREPLACE('[^a-z]',%'{@type}'%,'') IN ['unsigned','integer','real','decimal','udecimal'])
        #APPEND(cols,'+(STRING)LEFT.'+%'{@label}'%+'+\',\'')
      #END
    #END
  #END
  #SET(cols,%'cols'%[..LENGTH(%'cols'%)-4]+'+\']\'');
  RETURN '['+ROLLUP(PROJECT(dIn,TRANSFORM({STRING s;},SELF.s:=#EXPAND(%'cols'%);SELF:=LEFT;)),LEFT.s!=RIGHT.s,TRANSFORM({STRING s;},SELF.s:=LEFT.s+','+RIGHT.s;))[1].s+']';
ENDMACRO;

