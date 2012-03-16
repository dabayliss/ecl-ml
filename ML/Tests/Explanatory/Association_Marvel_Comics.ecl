/* //////////////////////////////////////////////////////////
/* //////////////////////////////////////////////////////////
MACHINE LEARNING EXAMPLE - Marvel Comics, Associations

			Step 1 - Mount snap-7766d116 to instance and symbolic link to drop zone
			Step 2 - Make necessary format changes to files
			Step 3 - Run through ML.Associate...
			Step 4 - Find all Captain America references
	////////////////////////////////////////////////////////// */
////////////////////////////////////////////////////////// */

IMPORT ML, STD;
IMPORT ML.Docs AS Docs;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////* INPUT FILES *///////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

layout_vertices := record
	string filler := '';
	string recordid;
	string values;
end;

DropZone_IP 			:= '10.68.26.62'; // use the private ip
Folder_Location 	:= 'mnt::dropzone::snap-7766d116'; //use :: to separate directories
Marvel_Inputfile	:= 'labeled_edges.tsv'; //file from Amazon Publicdata snap-7766d116

//////// Input File Used for Association
			raw_inputfile 				:= dataset('~file::'+DropZone_IP+'::'+Folder_Location+'::'+Marvel_Inputfile, {string character, string comicbook}, csv(separator('\t'), quote('"')));

			character_vertex 			:= project(dedup(sort(raw_inputfile, character), character), 
																				transform(layout_vertices,
																									self.filler := '';
																									self.recordid := (string)counter;
																									self.values := left.character));

			comicbook_vertex 			:= project(dedup(sort(raw_inputfile, comicbook), comicbook), 
																				transform(layout_vertices,
																									self.filler := '';
																									self.recordid := (string)counter + 'CB';
																									self.values := left.comicbook));

			raw_inputfilechar			:= join(raw_inputfile, character_vertex, left.character = right.values,
																					transform({recordof(raw_inputfile), string character_recordid, string comicbook_recordid := '', string values := ''},
																										self.character_recordid := right.recordid;
																										self.values := self.character_recordid;
																										self := left));
																										

			raw_inputfilecomic		:= join(raw_inputfilechar, comicbook_vertex, left.comicbook = right.values,
																					transform({recordof(raw_inputfilechar)},
																										self.comicbook_recordid := right.recordid;
																										self := left));
																										

			characterspercomicbk	:= rollup(raw_inputfilecomic, comicbook_recordid,
																					transform({recordof(raw_inputfilechar)},
																										self.values := left.values + ' ' + right.values;
																										self := left));
																										
																
			inputfile							:= project(characterspercomicbk,
																					transform(layout_vertices,
																										self.values := left.values;
																										self.recordid := left.comicbook_recordid;
																										self := []));
																										

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////* PERFORM ML ASSOCIATION *////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

TransformFile		:= PROJECT(inputfile,TRANSFORM(Docs.Types.Raw,SELF.Txt := LEFT.values));
Enumerate	 			:= Docs.Tokenize.Enumerate(TransformFile);
SplitFields 		:= Docs.Tokenize.Split(Enumerate);
Lexicon 				:= Docs.Tokenize.Lexicon(SplitFields);
TokenizeFields 	:= Docs.Tokenize.ToO(SplitFields,Lexicon);
WordBag					:= Docs.Trans(TokenizeFields).WordBag;

ForAssoc 			:= PROJECT(WordBag, TRANSFORM(ML.Types.ItemElement,
																					SELF.id := LEFT.id,
																					SELF.value := LEFT.word));
																		
AssociationsApriori3 	:= ML.Associate(ForAssoc,2).Apriori3;
AssociationsEclat 		:= ML.Associate(ForAssoc,2).EclatN(3);

Return_ML_Results := 
parallel(
	output(TransformFile, named('Step1_Transform_File'));
	output(Enumerate, named('Step2_Enumerate'));
	output(SplitFields, named('Step3_Split_Fields'));
	output(Lexicon, named('Step4_Lexicon'));
	output(TokenizeFields, named('Step5_Tokenize_Fields'));
	output(WordBag, named('Step6_WordBag'));
	output(ForAssoc, named('Step7_Transform_For_Association'));
	output(sort(AssociationsApriori3, -support),,'out::Apriori3_Results', overwrite, named('Apriori3_Results'));
	output(sort(AssociationsEclat, -support),,'out::EclatN_Results', overwrite, named('EclatN_Results'));
);


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////* FIND CAPTAIN AMERICA *//////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

fnFindCaptainAmerica(dataset(recordof(AssociationsApriori3)) Associations) := function

captain_america_recordids := set(character_vertex(regexfind('CAPTAIN AMERICA', std.str.touppercase(values))), recordid);

filter_captain_america_associations := Associations((string)value_1 in captain_america_recordids or
																										(string)value_2 in captain_america_recordids or
																										(string)value_3 in captain_america_recordids);

jnValue1 := join(filter_captain_america_associations, character_vertex + comicbook_vertex,
									(string)left.value_1 = right.recordid,
									transform({recordof(filter_captain_america_associations), string value_1_desc, string value_2_desc, string value_3_desc},
														self.value_1_desc := if(right.recordid <> '', right.values, (string)left.value_1),
														self := left,
														self := []), left outer);
														
jnValue2 := join(jnValue1, character_vertex + comicbook_vertex,
									(string)left.value_2 = right.recordid,
									transform(recordof(jnValue1),
														self.value_2_desc := if(right.recordid <> '', right.values, (string)left.value_2),
														self := left), left outer);
														
return join(jnValue2, character_vertex + comicbook_vertex,
									(string)left.value_3 = right.recordid,
									transform(recordof(jnValue1),
														self.value_3_desc := if(right.recordid <> '', right.values, (string)left.value_3),
														self := left), left outer);
end;

TrAssociationsEclat := project(AssociationsEclat, transform(recordof(AssociationsApriori3),
																															ppat := left.pat + '   ';
																														self.value_1 := (unsigned)ppat[..std.str.find(ppat, ' ', 1)-1];
																														self.value_2 := (unsigned)ppat[std.str.find(ppat, ' ', 1)+1..std.str.find(ppat, ' ', 2)-1];
																														self.value_3 := (unsigned)ppat[std.str.find(ppat, ' ', 2)+1..std.str.find(ppat, ' ', 3)-1];
																														self := left));

CA_AssociationsApriori3 := fnFindCaptainAmerica(AssociationsApriori3);
CA_AssociationsEclat := fnFindCaptainAmerica(TrAssociationsEclat);

Return_Captain_America :=
parallel(
	output(sort(CA_AssociationsApriori3, -support),,'out::Captain_America_References_Apriori3', named('Captain_America_References_Apriori3'), OVERWRITE);
	output(sort(CA_AssociationsEclat, -support),,'out::Captain_America_References_Eclat', named('Captain_America_References_Eclat'), OVERWRITE);
);

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////* RETURN ALL RESULTS *////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Return_ML_Results;
Return_Captain_America;

