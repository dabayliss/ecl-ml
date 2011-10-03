// Various tests to see if a matrix is a particular type
IMPORT * FROM $;
EXPORT Is(DATASET(Types.Element) d) := MODULE

SHARED dn := Thin(d);

// Matrix with only zeroes
EXPORT Zero := ~EXISTS(dn);

// Matrix only has entries along diagonal - note - zero matrix is diagonal by this definition
EXPORT Diagonal := ~EXISTS(dn(x<>y));

// Scalar definition - all leading entries must exist - and must be equal
EXPORT Scalar := Diagonal AND COUNT(dn)=MAX(dn,x) AND MAX(dn,value)=MIN(dn,value);

// Matrix is an identity matrix
EXPORT Identity := Scalar AND MAX(dn,value)=1;

// Is the matrix symmetric
EXPORT Symmetric := Eq(dn,Trans(dn));

  END;