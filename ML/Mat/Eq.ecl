IMPORT * FROM $;
EXPORT Eq(DATASET(Types.Element) l,DATASET(Types.Element) r) := FUNCTION
  lt := Thin(l);
	rt := Thin(r);
	//RETURN COUNT(lt)=COUNT(rt) AND Is(Sub(lt,rt)).Zero;
	RETURN COUNT(lt)=COUNT(rt) AND ~EXISTS(Thin(Sub(lt,rt)));
  END;