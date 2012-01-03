// Utilities for the implementation of ML (rather than the interface to it)
IMPORT * FROM $;
EXPORT Utils := MODULE

EXPORT Pi := 3.1415926535897932384626433;

EXPORT REAL8 Fac(UNSIGNED2 i) := BEGINC++
  double accum = 1.0;
	for ( int j = 2; j <= i; j++ )
		accum *= (double)j;
	return accum;
  ENDC++;

// The 'double' factorial is defined for ODD n and is the product of all the odd numbers up to and including that number
// We are extending the meaning to even numbers to mean the product of the even numbers up to and including that number
// Thus DoubleFac(8) = 8*6*4*2
// We also defend against i < 2 (returning 1.0)
EXPORT REAL8 DoubleFac(INTEGER2 i) := BEGINC++
  if ( i < 2 )
		return 1.0;
  double accum = (double)i;
	for ( int j = i-2; j > 1; j -= 2 )
		accum *= (double)j;
	return accum;
  ENDC++;

// N Choose K - finds the number of combinations of K elements out of a possible N
// Should eventually do this in a way to avoid the intermediates (such as Fac(N)) exploding
EXPORT REAL8 NCK(INTEGER2 N, INTEGER2 K) := Fac(N)/(Fac(K)*Fac(N-k));

// Evaluate a polynomial from a set of co-effs. Co-effs 1 is assumed to be the HIGH order of the equation
// Thus for ax^2+bx+c - the set would need to be Coef := [a,b,c];
EXPORT REAL8 Poly(REAL8 x, SET OF REAL8 Coeffs) := BEGINC++
  if (isAllCoeffs)
	  return 0.0;
	int num = lenCoeffs / 8; // Note - REAL8 specified in prototype
	if ( num == 0 )
		return 0.0;
	const double * cp = (const double *)coeffs; // Will not work if sizeof(double) != 8
	double tot = *cp++;
	while ( --num )
		tot = tot * x + *cp++;
	return tot;
  ENDC++;

EXPORT stirlingFormula(real8 x) :=FUNCTION
	 stirCoefs :=[7.87311395793093628397E-4,
								-2.29549961613378126380E-4,
								-2.68132617805781232825E-3,
								3.47222221605458667310E-3,
								8.33333333333482257126E-2];
												
		REAL8 stirmax := 143.01608;
    REAL8 w := 1.0/x;
    REAL8  y := exp(x);

    v := 1.0 + w * Poly(w, stirCoefs);
    
		z := IF(x > stirmax, POWER(x,0.5 * x - 0.25), //Avoid overflow in Math.pow()
													POWER(x, x - 0.5)/y);
		u := IF(x > stirmax, z*(z/y), z);
		
    RETURN SQRT(PI)*u*v;
end;
/*
	return the value of gamma function of real number x
  The implementation references open source weka gamma function but does not strictly follow it
	12/02/2011
*/
EXPORT gamma(REAL8 x) :=FUNCTION
	P :=[
			1.60119522476751861407E-4,
      1.19135147006586384913E-3,
      1.04213797561761569935E-2,
      4.76367800457137231464E-2,
      2.07448227648435975150E-1,
      4.94214826801497100753E-1,
      9.99999999999999996796E-1];
	
	Q :=[
			-2.31581873324120129819E-5,
      5.39605580493303397842E-4,
      -4.45641913851797240494E-3,
      1.18139785222060435552E-2,
      3.58236398605498653373E-2,
      -2.34591795718243348568E-1,
      7.14304917030273074085E-2,
      1.00000000000000000320E0];
												
	 absx := abs(x);
	 intx := (INTEGER) absx;
	 isRightInt := (absx-intx)<1.0e-9;
	 isLeftInt :=ABS((ROUND(absx)-absx))<1.0e-9;
	 // x can't be zero or negative integer
	 isfail := absx<1.0e-9 OR (x<0 AND (isRightInt OR isLeftInt));
	 
	  // x is positive natural numbers 
		REAL8 g0 := IF( intx=1 OR intx=2, 1.0, fac(intx-1)); 
		
	  //x < -6
		REAL8 y := absx * SIN(PI*absx);
		REAL8 g1 := - PI/(y*stirlingFormula(absx));		
		REAL8 g2 := IF(x>6.0, stirlingFormula(x), g1);
		
		//abs(x) <6
		z0 := 1.0;
		z1 :=IF(x>3, MAP(//x>3
								    x >5 =>(x-1)*(x-2)*(x-3),
										x >4 =>(x-1)*(x-2),
										x >3 =>(x-1),
										1 
						       ), z0);
	  REAL8 x1 := IF(x>3, x-(INTEGER)x+2, x);
		
		//for x1<0
		z2 :=IF(x1<-1 AND x1 >-6,
						MAP(
						x1 <-5=>z1/(x1*(x1+1.0)*(x1+2.0)*(x1+3.0)*(x1+4.0)),
						x1 <-4 =>z1/(x1*(x1+1.0)*(x1+2.0)*(x1+3.0)),
						x1 <-3 =>z1/(x1*(x1+1.0)*(x1+2.0)),
						x1 <-2 => z1/(x1*(x1+1.0)),
						z1/x1
						), z1);
		x2 := IF(x1<-1 AND x1 >-6.0, x1+(INTEGER)ABS(x1), x1);
		REAL8 w0 := IF(x2<0 AND x2>-1.0E-9, z2/((1.0+0.5772156649015329 * x2)*x2),z2);
		z3 := IF(x2<-1.0E-9, z2/x2, z2);
		x3 := IF(x2<-1.0E-9, x2+1.0, x2);
		
		//x3>0 and x3<2
		REAL8 w1 := IF(x3<1.0E-9 AND x3>0, z3/((1.0+0.5772156649015329 * x3)*x3),z3);
	  z4 := IF(x3<2.0, IF(x3>1.0, z3/x3, z3/(x3*(x3+1.0))), z3);
	  x4 := IF(x3<2.0, IF(x3>1.0, x3+1, x3+2), x3);
	 
		x5 := x4-2.0;
		REAL8 u := Poly(x5,P);
		REAL8 v := Poly(x5,Q);
		REAL8 g3 := z4 * u / v;
		
	  REAL8 g := MAP(
						isFail => 9999,//FAIL(99, 'x should not be zero or negative integers'),
						x>1.0e-9 AND ((absx-intx)<1.0e-9 OR abs((round(absx)-absx))<1.0e-9) => g0,
						//x is big enough
						ABS(x)>=6.0 => g2,
						x2<0 AND x2>-1.0E-9 => w0,
						x3<1.0E-9 AND x3>0 => w1,
						g3);
		RETURN g;
END;

/*
	return the beta value of two real numbers, x and y
*/
EXPORT Beta(REAL8 x, REAL8 y) := FUNCTION
	 absx := ABS(x);
	 intx := (INTEGER) absx;
	 isXRightInt := (absx-intx)<1.0e-9;
	 isXLeftInt :=ABS((ROUND(absx)-absx))<1.0e-9;
	 isXfail := absx<1.0e-9 OR (x<0 AND (isXRightInt OR isXLeftInt));
	 
	 absy := ABS(y);
	 inty := (INTEGER) absy;
	 isYRightInt := (absy-inty)<1.0e-9;
	 isYLeftInt :=ABS((ROUND(absy)-absy))<1.0e-9;
	 isYfail := absy<1.0e-9 OR (y<0 AND (isYRightInt OR isYLeftInt));
	 
	 bp := gamma(x)*gamma(y)/gamma(x+y);
	 bn :=(x+y)*gamma(x+1)*gamma(y+1)/(x*y*gamma(x+y+1));
	
	 b := MAP(
						x>0 AND y>0 => bp,
						isXfail OR isYfail => 9999, // failed becuase one of them negative integers or zero
						bn //when both x and y negative real numbers				
					 );
					
	RETURN b;
END;

// In constrast to the matrix function thin
// Will take a potentially sparse file d and fill in the blanks with value v
EXPORT Fat(DATASET(Types.NumericField) d0,Types.t_FieldReal v=0) := FUNCTION
  dn := DISTRIBUTE(d0,HASH(id)); // all the values for a given ID now on one node
  seeds := TABLE(dn,{id,m := MAX(GROUP,number)},id,LOCAL); // get the list of ids on each node (and get 'max' number for free
	mn := MAX(seeds,m); // The number of fields to fill in
	Types.NumericField bv(seeds le,UNSIGNED C) := TRANSFORM
	  SELF.value := v;
		SELF.id := le.id;
		SELF.number := c;
	END;
	// turn n into a fully 'blank' matrix - distributed along with the 'real' data
	n := NORMALIZE(seeds,mn,bv(LEFT,COUNTER),LOCAL); 
	// subtract from 'n' those values that already exist
	n1 := JOIN(n,dn,LEFT.id=RIGHT.id AND LEFT.number=RIGHT.number,TRANSFORM(LEFT),LEFT ONLY,LOCAL);
	RETURN n1+dn;
END;
	
// Given a file which is sorted by INFIELD (and possibly other values), add sequence numbers within the range of each infield
// Slighly elaborate code is to avoid having to partition the data to one value of infield per node
EXPORT mac_SequenceInField(infile,infield,seq,outfile) := MACRO

#uniquename(add_rank)
TYPEOF(infile) %add_rank%(infile le,UNSIGNED c) := TRANSFORM
  SELF.seq := c;
	SELF := le;
  END;
	
#uniquename(P)
%P% := PROJECT(infile,%add_rank%(LEFT,COUNTER));

#uniquename(RS)
%RS% := RECORD
  __Seq := MIN(GROUP,%P%.seq);
  %P%.infield;
  END;

#uniquename(Splits)
%Splits% := TABLE(%P%,%RS%,infield,FEW);

#uniquename(to_1)
TYPEOF(infile) %to_1%(%P% le,%Splits% ri) := TRANSFORM
	SELF.Seq := 1+le.Seq - ri.__Seq;
	SELF := le;
  END;
	
outfile := JOIN(%P%,%Splits%,LEFT.InField=RIGHT.InField,%to_1%(LEFT,RIGHT),LOOKUP);

ENDMACRO;

// Shift the column-numbers of a file of discretefields so that the left-most column is now new_lowval
// Can move colums left or right (or not at all)
EXPORT RebaseDiscrete(DATASET(Types.DiscreteField) cl,Types.t_FieldNumber new_lowval) := FUNCTION
  CurrentBase := MIN(cl,number);
	INTEGER Delta := new_lowval-CurrentBase;
	RETURN PROJECT(cl,TRANSFORM(Types.DiscreteField,SELF.number := LEFT.number+Delta,SELF := LEFT));
  END;

EXPORT RebaseNumericField(DATASET(Types.NumericField) cl) := MODULE
  SHARED MapRec:=RECORD
		Types.t_FieldNumber old;
		Types.t_FieldNumber new;
	END;
  olds := TABLE(cl, {cl.number,COUNT(GROUP)}, number, FEW);	
	
	EXPORT Mapping(Types.t_FieldNumber new_lowval=1) := FUNCTION
	MapRec mapthem(olds le, UNSIGNED c) := TRANSFORM
		SELF.old := le.number;
		SELF.new := c-1+new_lowval;
	END;
		RETURN PROJECT(olds, mapthem(LEFT, COUNTER));
	END;
		
	EXPORT ToNew(DATASET(MapRec) MapTable) := FUNCTION
 		RETURN JOIN(cl,MapTable,LEFT.number=RIGHT.old,TRANSFORM(Types.NumericField, SELF.number := RIGHT.new, SELF:=LEFT),LOOKUP);
  END;	
	
	EXPORT ToOld(DATASET(Types.NumericField) cl, DATASET(MapRec) MapTable) := FUNCTION
 		RETURN JOIN(cl,MapTable,LEFT.number=RIGHT.new,TRANSFORM(Types.NumericField, SELF.number := RIGHT.old, SELF:=LEFT),LOOKUP);
  END;	
	
  END;	
	

	
	
END;