IMPORT ML;

// Simple examples of distribution module
// Construct a StudentT distribution - and find the tails of it (as you would in a statistics book!)
a := ML.Distribution.StudentT(3,10000);
a.NTile(99); // Single tail
a.NTile(99.5); // Double tail
// Generate 1000000 data values in column 4 using distribution a
ML.Distribution.GenData(1000000,a,4);