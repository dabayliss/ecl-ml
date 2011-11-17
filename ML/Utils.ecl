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
	
END;