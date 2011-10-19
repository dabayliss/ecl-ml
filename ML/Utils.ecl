// Utilities for the implementation of ML (rather than the interface to it)
IMPORT * FROM $;
EXPORT Utils := MODULE

// In constrast to the matrix function thin
// Will take a potentially sparse file d and fill in the blanks with value v
EXPORT Fat(DATASET(Types.NumericField) d,Types.t_FieldReal v=0) := FUNCTION
  dn := DISTRIBUTE(d,HASH(id)); // all the values for a given ID now on one node
  seeds := TABLE(d,{id,m := MAX(GROUP,number)},id,LOCAL); // get the list of ids on each node (and get 'max' number for free
	mn := MAX(seeds,m); // The number of fields to fill in
	Types.NumericField bv(seeds le,UNSIGNED C) := TRANSFORM
	  SELF.value := v;
		SELF.id := le.id;
		SELF.number := c;
	END;
	// turn n into a fully 'blank' matrix - distributed along with the 'real' data
	n := NORMALIZE(seeds,mn,bv(LEFT,COUNTER),LOCAL); 
	// subtract from 'n' those values that already exist
	n1 := JOIN(n,d,LEFT.id=RIGHT.id AND LEFT.number=RIGHT.number,TRANSFORM(LEFT),LEFT ONLY);
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
	
END;