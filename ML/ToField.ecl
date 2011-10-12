EXPORT ToField(dIn,dOut):=MACRO
  LOADXML('<xml/>');
  #DECLARE(idfield) #SET(idfield,'')
  #DECLARE(fieldlist) #SET(fieldlist,'COUNTER')
  #DECLARE(iPivotLoop) #SET(iPivotLoop,0)
  #EXPORTXML(fields,RECORDOF(dIn))
  #FOR(fields)
    #FOR(Field)
      #IF(%iPivotLoop%=0)
        #SET(idfield,%'{@label}'%);
      #ELSE
        #APPEND(fieldlist,',LEFT.'+%'{@label}'%)
      #END
      #SET(iPivotLoop,%iPivotLoop%+1)
    #END
  #END
  dOut:=NORMALIZE(dIn,%iPivotLoop%-1,TRANSFORM(ML.Types.NumericField,SELF.id:=LEFT.#EXPAND(%'idfield'%),SELF.number:=COUNTER;SELF.value:=CHOOSE(#EXPAND(%'fieldlist'%))));
ENDMACRO;
