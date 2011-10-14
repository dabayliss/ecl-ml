// Matrix Properties
IMPORT * FROM $;
EXPORT Has(DATASET(Types.Element) d) := MODULE

SHARED dn := Thin(d);

xMax := MAX(dn, x);
yMax := MAX(dn, y);
EXPORT Dimension := IF (xMax>yMax, xMAx, yMax);

END;