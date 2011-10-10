IMPORT * FROM $;
EXPORT RoundDelta(DATASET(Types.Element) d, real delta) := PROJECT(d, TRANSFORM(Types.Element, 
																											SELF.value := IF(ABS(LEFT.value-ROUND(LEFT.value))<delta ,ROUND(LEFT.value), LEFT.value ), SELF := LEFT));