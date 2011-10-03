EXPORT Types := MODULE

// Note - indices will start at 1; 0 is going to be used as a null
EXPORT t_Index := UNSIGNED4; // Supports matrices with up to 9B as the largest dimension
EXPORT t_value := REAL8;

EXPORT Element := RECORD
  t_Index x;
	t_Index y;
	t_value value;
END;

END;