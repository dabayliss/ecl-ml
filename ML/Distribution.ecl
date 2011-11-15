IMPORT * FROM ML;
IMPORT * FROM ML.Types;
IMPORT ML.Mat;
IMPORT ML.Mat.Vec AS Vec;
// This module exists to provide routines to support the various statistical distribution functions that exist
EXPORT Distribution := MODULE

SHARED Pi := 3.1415926535897932384626433;

// Used for storing a vector of probabilities (usually cumulative)
EXPORT Layout := RECORD
  t_Count RangeNumber;
	t_FieldReal RangeHigh;
	t_FieldReal P;
  END;

// NRanges is the number of divisions to split the distribution into	
EXPORT Default(t_Count NRanges) := MODULE,VIRTUAL
  EXPORT t_FieldReal Density(t_FieldReal RangeHigh) := 0.0; // Density function at stated point
	EXPORT t_FieldReal Cumulative(t_FieldReal RangeHigh) := 0.0; // Cumulative probability at stated point
  EXPORT DensityVec() := DATASET([],Layout); // Probability of between >PreviosRangigh & <= RangeHigh
	EXPORT CumulativeVec() := DATASET([],Layout); // Table of probabilies from -inf <= RangeHigh
  END;

// Assume probabilities are uniformly distributed across low/high	
EXPORT Uniform(t_FieldReal low,t_FieldReal high,t_Count NRanges = 10000) := MODULE(Default(NRanges))
  SHARED t_FieldReal RangeWidth := (high-low)/NRanges;
  EXPORT t_FieldReal Density(t_FieldReal RangeHigh) := IF (RangeHigh >= low AND RangeHigh <= high,1/NRanges,0);
	EXPORT t_FieldReal Cumulative(t_FieldReal RangeHigh) := MAP ( RangeHigh <= low => 0,
																										RangeHigh >= high => 1,
																										(RangeHigh-low) / (high-low) );

  EXPORT DensityVec() := PROJECT(Vec.From(NRanges),TRANSFORM(Layout,SELF.RangeNumber:=LEFT.i,SELF.RangeHigh:=low+LEFT.i*RangeWidth,SELF.P := Density(low+LEFT.i*RangeWidth)));
  EXPORT CumulativeVec() := PROJECT(Vec.From(NRanges),TRANSFORM(Layout,SELF.RangeNumber:=LEFT.i,SELF.RangeHigh:=low+LEFT.i*RangeWidth,SELF.P := Cumulative(low+LEFT.i*RangeWidth)));	
  END;

// A normal distribution with mean 'mean' and standard deviation 'sd'
EXPORT Normal(t_FieldReal mean,t_FieldReal sd,t_Count NRanges = 10000) := MODULE(Default(NRanges))
  SHARED t_FieldReal Var := sd*sd;
	SHARED fn_Density(t_FieldReal x,t_FieldReal mu,t_FieldReal sig_sq) := EXP( - POWER(x-mu,2)/(2*sig_sq) )/SQRT(2*Pi*Sig_Sq);
	// Standard definition of normal probability density function
  EXPORT t_FieldReal Density(t_FieldReal RangeHigh) := fn_Density(RangeHigh,Mean,Var);

  // using the Abromowitz and Stegun Approximation to the CDF; accurate to about 8 sig figs
	EXPORT t_FieldReal Cumulative(t_FieldReal RangeHigh) := FUNCTION
		// Need to convert to the equivalent in the N(0,1) realm
	  REAL Scaled := ABS(RangeHigh-mean)/sd;
	  REAL8 t := 1 / (1+0.2316419 * Scaled);
	  P := 1 - fn_Density(Scaled,0,1)*(0.319381530*t-0.356563782*t*t+1.781477937*POWER(t,3)-1.821255978*POWER(t,4)+1.330274429*POWER(t,5));
		RETURN IF( RangeHigh < Mean,1 - P, P );
	END;
  // Assume the range of a normal function is 4 sd above and below the mean
	SHARED low := mean-4*sd;
	SHARED high := mean+4*sd;
	SHARED RangeWidth := (high-low)/NRanges;
  EXPORT DensityVec() := PROJECT(Vec.From(NRanges),TRANSFORM(Layout,SELF.RangeNumber:=LEFT.i,SELF.RangeHigh:=low+LEFT.i*RangeWidth,SELF.P := Density(low+LEFT.i*RangeWidth)));
  EXPORT CumulativeVec() := PROJECT(Vec.From(NRanges),TRANSFORM(Layout,SELF.RangeNumber:=LEFT.i,SELF.RangeHigh:=low+LEFT.i*RangeWidth,SELF.P := Cumulative(low+LEFT.i*RangeWidth)));	

  END;

  END;