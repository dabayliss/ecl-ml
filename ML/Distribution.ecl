IMPORT * FROM ML;
IMPORT * FROM ML.Types;
IMPORT ML.Mat;
IMPORT ML.Mat.Vec AS Vec;
// This module exists to provide routines to support the various statistical distribution functions that exist
EXPORT Distribution := MODULE

// Used for storing a vector of probabilities (usually cumulative)
EXPORT Layout := RECORD
  t_Count RangeNumber;
	t_FieldReal RangeHigh;
	t_FieldReal P;
  END;

// NRanges is the number of divisions to split the distribution into	
EXPORT Default(t_Count NRanges) := MODULE,VIRTUAL
  EXPORT t_FieldReal Density(t_FieldReal RH) := 0.0; // Density function at stated point
	EXPORT t_FieldReal Cumulative(t_FieldReal RH) := 0.0; // Cumulative probability at stated point
  EXPORT DensityV() := DATASET([],Layout); // Probability of between >PreviosRangigh & <= RangeHigh
	EXPORT CumulativeV() := DATASET([],Layout); // Table of probabilies from -inf <= RangeHigh
  END;

// Assume probabilities are uniformly distributed across low/high	
EXPORT Uniform(t_FieldReal low,t_FieldReal high,t_Count NRanges = 10000) := MODULE(Default(NRanges))
  SHARED t_FieldReal RangeWidth := (high-low)/NRanges;
  EXPORT t_FieldReal Density(t_FieldReal RH) := IF (RH >= low AND RH <= high,1/NRanges,0);
	EXPORT t_FieldReal Cumulative(t_FieldReal RH) := MAP ( RH <= low => 0,
																										RH >= high => 1,
																										(RH-low) / (high-low) );

  EXPORT DensityV() := PROJECT(Vec.From(NRanges),TRANSFORM(Layout,SELF.RangeNumber:=LEFT.i,SELF.RangeHigh:=low+LEFT.i*RangeWidth,SELF.P := Density(low+LEFT.i*RangeWidth)));
  EXPORT CumulativeV() := PROJECT(Vec.From(NRanges),TRANSFORM(Layout,SELF.RangeNumber:=LEFT.i,SELF.RangeHigh:=low+LEFT.i*RangeWidth,SELF.P := Cumulative(low+LEFT.i*RangeWidth)));	
  END;

// A normal distribution with mean 'mean' and standard deviation 'sd'
EXPORT Normal(t_FieldReal mean,t_FieldReal sd,t_Count NRanges = 10000) := MODULE(Default(NRanges))
  SHARED t_FieldReal Var := sd*sd;
	// Standard definition of normal probability density function
	SHARED fn_Density(t_FieldReal x,t_FieldReal mu,t_FieldReal sig_sq) := EXP( - POWER(x-mu,2)/(2*sig_sq) )/SQRT(2*Utils.Pi*Sig_Sq);
  EXPORT t_FieldReal Density(t_FieldReal RH) := fn_Density(RH,Mean,Var);

  // using the Abromowitz and Stegun Approximation to the CDF; accurate to 7 decimal places
	EXPORT t_FieldReal Cumulative(t_FieldReal RH) := FUNCTION
		// Need to convert to the equivalent in the N(0,1) realm
	  REAL Scaled := ABS(RH-mean)/sd;
	  REAL8 t := 1 / (1+0.2316419 * Scaled);
	  P := 1 - fn_Density(Scaled,0,1)*(0.319381530*t-0.356563782*t*t+1.781477937*POWER(t,3)-1.821255978*POWER(t,4)+1.330274429*POWER(t,5));
		RETURN IF( RH < Mean,1 - P, P );
	END;
  // Assume the range of a normal function is 4 sd above and below the mean
	SHARED low := mean-4*sd;
	SHARED high := mean+4*sd;
	SHARED RangeWidth := (high-low)/NRanges;
  EXPORT DensityV() := PROJECT(Vec.From(NRanges),TRANSFORM(Layout,SELF.RangeNumber:=LEFT.i,SELF.RangeHigh:=low+LEFT.i*RangeWidth,SELF.P := Density(low+LEFT.i*RangeWidth)));
  EXPORT CumulativeV() := PROJECT(Vec.From(NRanges),TRANSFORM(Layout,SELF.RangeNumber:=LEFT.i,SELF.RangeHigh:=low+LEFT.i*RangeWidth,SELF.P := Cumulative(low+LEFT.i*RangeWidth)));	

  END;

// A poisson distribution has a mean and variance characterized by lamda
// Lamda need not be an integer although it is used to produce probabilities for a count of discrete events
// It speaks to the question - given I fall over on average 1.6 times a day; what are the chances of me falling over twice today?
// In particular NRanges is a little different for this distribution - it assumes we want probabilities for between 0 and n-1 events
EXPORT Poisson(t_FieldReal lamda,t_Count NRanges = 100) := MODULE(Default(NRanges))
  // This has to take a real for 'derivation' reasons - but range-high must be an 'integer' from 0->NRanges-1 to be meaningful
  EXPORT t_FieldReal Density(t_FieldReal RH) := EXP(-lamda)*POWER(lamda,RH)/Utils.Fac(RH);
  EXPORT DensityV() := PROJECT(Vec.From(NRanges),TRANSFORM(Layout,SELF.RangeNumber:=LEFT.i,SELF.RangeHigh:=LEFT.i-1,SELF.P := Density(LEFT.i-1)));
  // We have a discrete a relatively small density vector; compute the Cumulative Vector by simply adding up!
  EXPORT CumulativeV() := FUNCTION
		d := DensityV();
		Layout Accum(Layout le,Layout ri) := TRANSFORM
		  SELF.p := le.p+ri.p;
		  SELF := ri;
		END;
		RETURN ITERATE(d,Accum(LEFT,RIGHT)); // Global iterates are horrible - but this should be tiny
	END;
	// This presumes it is better to compute the vector once and then use it - one could write a little C++ function if one wished
	EXPORT t_FieldReal Cumulative(t_FieldReal RH) := CumulativeV()(RangeHigh=RH)[1].p;
  END;


  END;