IMPORT * FROM ML.Mat;
IMPORT Config FROM ML;
// Thin down a sparse matrix by removing any elements which are now 0, while preserving the dimension element
// Encapsulated here in case we eventually want to incorporate some form of error-term in the 0 test
EXPORT Thin(DATASET(Mat.Types.Element) d) := FUNCTION
			Dim := Mat.Has(d).Stats;
			thinD := d(ABS(Value) > Config.RoundingError );
      RETURN Mat.SetDimension(thinD, Dim.XMax, Dim.YMax);
END;
