//---------------------------------------------------------------------------
// NOTE: THE GRAPHICS PACKAGE USD BY D3 IS *NOT* COMPATIBLE WITH INTERNET
// EXPLORER.  RESULTS FROM THESE EXAMPLES MUST BE VIEWED IN ANOTHER BROWSER
// SUCH AS CHROME OR FIREFOX.
//---------------------------------------------------------------------------
IMPORT VL;

// Fictitious Family tree relationship data
dRelatives:=DATASET([
  {5367,'David Breyer',236234},
  {470,'Meredith Breyer',16890},
  {555,'Madeline Kennedy',21},
  {21,'Leah Kennedy',236234},
  {198,'Nathan Breyer',236234},
  {5423,'Mackenzie Breyer',198},
  {7890,'Jaidyn Breyer',198},
  {236234,'Donna Breyer',7534},
  {567,'Luca Breyer',5367},
  {8887,'Iago Breyer',5367},
  {80123,'Hannah Breyer',16890},
  {165879,'Alice Alito',7534},
  {2422,'Trevor Breyer',16890},
  {2424,'Hayes Breyer',16890},
  {7769,'Eliza Kennedy',21},
  {16890,'Andrew Breyer',236234},
  {9023,'Shay Thomas',236234},
  {7534,'Clarence Ginsburg Jr.',555},
  {123456,'Kris Roberts',83265},
  {705948,'Lindsay Roberts',123456},
  {83265,'Sandra Sotomayor',7534},
  {2345,'Ty Kagan',675645},
  {27,'Brice Kagan',675645},
  {20,'Bret Roberts',123456},
  {675645,'Joy Kagan',83265},
  {80124,'Kelsey Roberts',123456},
  {43546,'Tracy Scalia',83265},
  {3000,'Sarah Scalia',43546},
  {1024,'Matthew Scali',43546}
],{UNSIGNED id;STRING name;UNSIGNED parent;});

dLabels:=PROJECT(dRelatives,TRANSFORM(VL.Types.GraphLabels,SELF.label:=LEFT.name;SELF:=LEFT;));
dRelationships:=PROJECT(dRelatives,TRANSFORM(VL.Types.GraphRelationships,SELF.id:=LEFT.parent;SELF.linkid:=LEFT.id;))(id!=555);

VL.D3.Graph('Tree','FamilyTree',dLabels,dRelationships);
VL.D3.Graph('Chord','FamilyChord',dLabels,dRelationships);
