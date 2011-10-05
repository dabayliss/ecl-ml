IMPORT ML;
EXPORT Types := MODULE

// Note - indices will start at 1; 0 is going to be used as a null
EXPORT t_Index := UNSIGNED4; // Supports matrices with up to 9B as the largest dimension
EXPORT t_value := REAL8;
EXPORT t_mu_no := UNSIGNED2; // Allow up to 64K matrices in one universe

EXPORT Element := RECORD
  t_Index x;
	t_Index y;
	t_value value;
END;

EXPORT MUElement := RECORD(Element)
	t_mu_no no; // The number of the matrix within the universe
END;

EXPORT ToMatrix(DATASET(ML.Types.NumericField) d):=FUNCTION
  RETURN PROJECT(d,TRANSFORM(Element,SELF.x:=(TYPEOF(Element.x))LEFT.id;SELF.y:=(TYPEOF(Element.y))LEFT.number;SELF.value:=(TYPEOF(Element.value))LEFT.value;));
END;

EXPORT FromMatrix(DATASET(Element) d):=FUNCTION
  RETURN PROJECT(d,TRANSFORM(ML.Types.NumericField,SELF.id:=(TYPEOF(ML.Types.NumericField.id))LEFT.x;SELF.number:=(TYPEOF(ML.Types.NumericField.number))LEFT.y;SELF.value:=(TYPEOF(ML.Types.NumericField.value))LEFT.value;));
END;

END;