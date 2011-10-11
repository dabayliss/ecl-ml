IMPORT Types FROM $;
IMPORT Config FROM ML;
// Thin down a sparse matrix by removing any elements which are now 0
// Encapsulated here in case we eventually want to incorporate some form of error-term in the 0 test
EXPORT Thin(DATASET(Types.Element) d) := d(ABS(Value) > Config.RoundingError );