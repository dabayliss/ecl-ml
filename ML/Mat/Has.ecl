// Matrix Properties
IMPORT * FROM $;
EXPORT Has(DATASET(Types.Element) d) := MODULE

r := RECORD
  UNSIGNED NElements := COUNT(GROUP);
	UNSIGNED XMax := MAX(GROUP,d.x);
	UNSIGNED YMax := MAX(GROUP,d.y);
  END;

EXPORT Stats := TABLE(d,r)[1];

// The largest dimension of the matrix
EXPORT Dimension := MAX(Stats.XMax,Stats.YMax);

// The percentage of the sparse matrix that is actually there
EXPORT Density := Stats.NElements / (Stats.XMax*Stats.YMax);

EXPORT Norm := SQRT(SUM(Each.Mul(d,d),value));

END;