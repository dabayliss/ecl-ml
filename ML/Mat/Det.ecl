IMPORT * FROM $;

EXPORT Det(DATASET(Types.Element) matrix) := ROLLUP(LU.Decompose(matrix)(x=y), true, TRANSFORM(Types.Element, SELF.value := LEFT.value*RIGHT.value; SELF := LEFT));

