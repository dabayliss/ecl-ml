IMPORT * FROM $;
EXPORT Trans(DATASET(Types.Element) d) := PROJECT(d,TRANSFORM(Types.Element, SELF.x := LEFT.y, SELF.y := LEFT.x, SELF := LEFT));
