EXPORT macUnPivot(dIn,lOut,dOut):=MACRO
  LOADXML('<xml/>');
  #DECLARE(iUnPivotLoop) #SET(iUnPivotLoop,0)
	#DECLARE(assignments) #SET(assignments,'')
	#DECLARE(rid)
  #EXPORTXML(fields,lOut)
  #FOR(fields)
    #FOR(Field)
      #IF(%iUnPivotLoop%=0)
        #SET(rid,%'{@label}'%);
      #ELSE
        #APPEND(assignments,'SELF.'+%'{@label}'%+':=LEFT.'+%'{@label}'%+'+IF(RIGHT.number='+%'iUnPivotLoop'%+',RIGHT.value,0);')
      #END
      #SET(iUnPivotLoop,%iUnPivotLoop%+1)
    #END
  #END
	#UNIQUENAME(dDistributed)
	%dDistributed%:=SORT(DISTRIBUTE(dIn,id),id,LOCAL);
	#UNIQUENAME(dIDs)
	%dIDs%:=PROJECT(TABLE(%dDistributed%,{id},id,LOCAL),TRANSFORM(lOut,SELF.#EXPAND(%'rid'%):=LEFT.id;SELF:=[];));
	dOut:=DENORMALIZE(%dIDs%,%dDistributed%,LEFT.#EXPAND(%'rid'%)=RIGHT.id,TRANSFORM(lOut,#EXPAND(%'assignments'%)SELF:=LEFT;),LOCAL);
ENDMACRO;