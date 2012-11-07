// Constants used in PB BLAS
EXPORT Constants := MODULE
  EXPORT Block_Minimum := 100000;   // minimum cells in a block
  EXPORT Block_NoSplit := 200000;   // minimum to split into blocks
  EXPORT Block_Maximum := 10000000; // Maximum cells in a block

  // Message strings
  EXPORT Dimension_Incompat := 'Matrix dimensions are incompatible';
  EXPORT Distribution_Error := 'Matrix not distributed correctly';
  EXPORT Not_Square         := 'Matrix is not square';
END;