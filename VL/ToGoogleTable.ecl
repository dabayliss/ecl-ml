//---------------------------------------------------------------------------
// Macro to convert a rectangular matrix into a data table that can be read
// by Google Charts.
// NOTE: To accommodate the use of timelines, we are using a specific
// convention to delineate fields with dates in them.  Any such field should
// be a STRING8 field in YYYYMMDD format, and the first four characters in
// the name of the field should be "DATE".
//---------------------------------------------------------------------------
EXPORT ToGoogleTable(dIn):=FUNCTIONMACRO
  LOADXML('<xml/>');
  #DECLARE(cols) #SET(cols,'cols:[')
  #DECLARE(proj) #SET(proj,'PROJECT('+#TEXT(dIn)+',TRANSFORM({STRING s},SELF.s:=IF(COUNTER=1,\'\',\',\')+\'{c:[')
  #DECLARE(fieldtype)
  #DECLARE(fielddef)
  #DECLARE(comma) #SET(comma,'')
  #EXPORTXML(fields,RECORDOF(dIn))
  #FOR(fields)
    #FOR(Field)
      #IF(%'{@label}'%[..4]='date')
        #SET(fieldtype,'date')
        #SET(fielddef,'new DATE(\'+(STRING)LEFT.'+%'{@label}'%+'[..4]+\',\'+(STRING)LEFT.'+%'{@label}'%+'[5..6]+\',\'+(STRING)LEFT.'+%'{@label}'%+'[7..8]+\')')
      #ELSE
        #IF(REGEXREPLACE('[^a-z]',%'{@type}'%,'') IN ['unsigned','integer','real','decimal','udecimal'])
          #SET(fieldtype,'number')
          #SET(fielddef,'\'+(STRING)LEFT.'+%'{@label}'%+'+\'')
        #ELSE
          #SET(fieldtype,'string')
          #SET(fielddef,'\\\'\'+(STRING)LEFT.'+%'{@label}'%+'+\'\\\'')
        #END
      #END
      #APPEND(cols,%'comma'%+'{id:\''+%'{@label}'%+'\',label:\''+%'{@label}'%+'\',type:\''+%'fieldtype'%+'\'}')
      #APPEND(proj,%'comma'%+'{v:'+%'fielddef'%+'}')
      #SET(comma,',')
    #END
  #END
  #SET(cols,'var data=new google.visualization.DataTable({'+%'cols'%+'],rows:[')
  #SET(proj,%'proj'%+']}\';))')
  RETURN DATASET([{%'cols'%}],{STRING s})+#EXPAND(%'proj'%)+DATASET([{']});'}],{STRING s});
ENDMACRO;