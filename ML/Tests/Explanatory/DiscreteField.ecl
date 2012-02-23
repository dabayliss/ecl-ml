IMPORT ML;

// Simple illustration of the discretize module

// First create a regular 'ecl-style' record
value_record := RECORD
	unsigned rid;
  real height;
	real weight;
	real age;
	integer1 species; // 0 = human, 1 = tortoise
	integer1 gender; // 0 = unknown, 1 = male, 2 = female
  END;
	
d := dataset([{1,5*12+7,156*16,43,0,1},
							{2,5*12+7,128*16,31,0,2},
							{3,5*12+9,135*16,15,0,1},
							{4,5*12+7,145*16,14,0,1},
							{5,5*12-2,80*16,9,0,1},
							{6,4*12+8,72*16,8,0,1},
							{7,8,32,2.5,1,2},
							{8,6.5,28,2,1,2},
							{9,6.5,28,2,1,2},
							{10,6.5,21,2,1,1},
							{11,4,15,1,1,0},
							{12,3,10.5,1,1,0},
							{13,2.5,3,0.8,1,0},
							{14,1,1,0.4,1,0}							
							]
							,value_record);

ml.ToField(d,o);
o;
o1 := ML.Discretize.ByRounding(o);
o1