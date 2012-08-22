IMPORT VL;

// World population by region
// Source: UN Statistics Division
// Surface area is in km^2, population is in millions.
dRegions:=DATASET([
  {'Africa','Eastern Africa',6361,64.8,81.9,107.6,143.6,192.8,251.6,324},
  {'Africa','Middle Africa',6613,26.1,32,40.7,53.4,71.7,96.2,126.7},
  {'Africa','Northern Africa',8525,53,67.5,86.9,113.1,146.2,176.2,209.5},
  {'Africa','Southern Africa',2675,15.6,19.7,25.5,33,42.1,51.4,57.8},
  {'Africa','Western Africa',6138,70.5,85.6,107.4,139.8,182.5,235.7,304.3},
  {'Latin America','Caribbean',234,17.1,20.7,25.3,29.7,34.2,38.4,41.6},
  {'Latin America','Central America',2480,37.9,51.7,69.6,91.8,113.2,135.6,155.9},
  {'Latin America','South America',17832,112.4,147.7,191.5,240.9,295.6,347.4,392.6},
  {'North America','Northern America',21776,171.6,204.3,231.3,254.5,281.2,313.3,344.5},
  {'Asia','Eastern Asia',11763,672.4,801.5,984.1,1178.6,1359.1,1495.3,1574},
  {'Asia','Southern Asia',10791,507.1,620,778.8,986,1246.4,1515.6,1764.9},
  {'Asia','South-Eastern Asia',4495,172.9,219.3,285.2,359,445.4,523.8,593.4},
  {'Asia','Western Asia',4831,51,66.8,86.9,114,148.6,184.4,232},
  {'Europe','Eastern Europe',18814,220.1,252.8,276.2,294.9,310.5,304.2,294.8},
  {'Europe','Northern Europe',1810,78,81.9,87.4,89.9,92.1,94.3,99.2},
  {'Europe','Southern Europe',1317,108.3,117.4,126.8,137.7,142.4,145.1,115.2},
  {'Europe','Western Europe',1108,140.8,151.8,165.5,170.4,175.4,183.1,189.1},
  {'Oceania','Australia and New Zealand',8012,10.1,12.7,15.5,17.9,20.5,23,26.6},
  {'Oceania','Melanesia',541,2.2,2.6,3.3,4.3,5.5,7,8.7},
  {'Oceania','Micronesia',3,.1,.2,.2,.3,.4,.5,.5},
  {'Oceania','Polynesia',8,.2,.3,.4,.5,.5,.6,.7}
],{STRING continent;STRING region;UNSIGNED surface_area;DECIMAL8_1 pop1950;DECIMAL8_1 pop1960;DECIMAL8_1 pop1970;DECIMAL8_1 pop1980;DECIMAL8_1 pop1990;DECIMAL8_1 pop2000;DECIMAL8_1 pop2010;});

// Break down the surface area data by continent
dContinentArea:=TABLE(dRegions,{continent;UNSIGNED surface_area:=SUM(GROUP,surface_area);},continent);
ContinentStyle:=VL.Styles.SetValue(Vl.Styles.Default,title,'Surface Area by Continent');  // Modified styles to include a title on the graph
dContinentChart:=VL.FormatCartesianData(dContinentArea,continent);                                 // 
VL.Google.Cartesian('PieChart','SurfaceAreaPie',dContinentChart,ContinentStyle);
VL.Google.Cartesian('BarChart','SurfaceAreaBar',dContinentChart,ContinentStyle);
VL.Google.Cartesian('ColumnChart','SurfaceAreaColumn',dContinentChart,ContinentStyle);

// Break down the population by region
dPopOnly:=PROJECT(dRegions,{RECORDOF(dRegions) AND NOT [continent,surface_area]});        // Remove unnecessary fields
dPopData:=VL.FormatCartesianData(dPopOnly,region);                                                 // Reformat to the VL ChartData format
dSwapped:=VL.SwapAxes(dPopData,'Decade');                                                 // Swap the X and Y axes so the Decade is X instead of country
PopStyle:=VL.Styles.SetValue(Vl.Styles.Default,title,'Population by Region over Time');   // Add a title
VL.Google.Cartesian('LineChart','PopulationByRegionLine',dSwapped,PopStyle);
VL.Google.Cartesian('AreaChart','PopulationByRegionArea',dSwapped,PopStyle);

// Filter for Africa, then present the population stats in a combo chart with
// an average trendline.
dAfrica:=PROJECT(dRegions(continent='Africa'),{RECORDOF(dRegions) AND NOT [continent,surface_area]});
dWithAverages:=dAfrica+TABLE(dAfrica,{
  STRING region:='Average';
  DECIMAL8_1 pop1950:=AVE(GROUP,pop1950);
  DECIMAL8_1 pop1960:=AVE(GROUP,pop1960);
  DECIMAL8_1 pop1970:=AVE(GROUP,pop1970);
  DECIMAL8_1 pop1980:=AVE(GROUP,pop1980);
  DECIMAL8_1 pop1990:=AVE(GROUP,pop1990);
  DECIMAL8_1 pop2000:=AVE(GROUP,pop2000);
  DECIMAL8_1 pop2010:=AVE(GROUP,pop2010);
});                                                                                       // Create a row to contain the averages of each field
dFormatted:=VL.SwapAxes(VL.FormatCartesianData(dWithAverages,region),'Decade');                    // Swap X and Y as in the above example
ComboStyle:=Vl.Styles.SetValue(Vl.Styles.Default,ChartAdvanced,'title:"Population Growth in Africa",seriesType:"bars",series:{5:{type:"line"}}');
VL.Google.Cartesian('ComboChart','AfricanPopulationGrowthCombo',dFormatted,ComboStyle);   // Using the ChartAdvanced field to free-type options in a format native to the API
                                                                                          // enabling us to add the non-standard option assigning series 5 a line chart type
                                                                                          // instead of bar.

// Prepare a grid of surface area to 2010 population, then produce a scatter chart
dPopByArea:=VL.FormatCartesianData(TABLE(dRegions,{surface_area;pop2010}),surface_area);
VL.Google.Cartesian('ScatterChart','PopulationByArea',dPopByArea,VL.Styles.SetValue(Vl.Styles.Default,title,'Population by Surface Area'));

// Present the population in map form.  Google's Geo does not shade by region
// so we need to convert the regions to countries first.
dRegionPop:=JOIN(dRegions,VL.Geo.RegionCodes,LEFT.region=RIGHT.region);
dPopByCountry:=JOIN(VL.Geo.CountryCodes,dRegionPop,LEFT.subcontinent_code=RIGHT.region_code,TRANSFORM({STRING3 iso_code;STRING3 continent_code;DECIMAL8_1 pop2010;},SELF:=LEFT;SELF:=RIGHT;));
VL.Google.Cartesian('GeoChart','WorldPopulation',VL.FormatCartesianData(TABLE(dPopByCountry,{iso_code;pop2010;}),iso_code),VL.Styles.Large);

// Present the population for Africa in map form, adding a little color.
AfricaStyle:=VL.Styles.SetValue(VL.Styles.Large,ChartAdvanced,'region:"002",colorAxis:{minValue:0,colors:["#FF0000","#00FF00"]}');
VL.Google.Cartesian('GeoChart','AfricaPopulation',VL.FormatCartesianData(TABLE(dPopByCountry(continent_code='002'),{iso_code;pop2010;}),iso_code),AfricaStyle);


// Additional Geo samples, showing US-specific data from the 2008 election results
dElectoralCollege:=DATASET([
  {'US-AL',9},{'US-AK',3},{'US-AZ',10},{'US-AR',6},{'US-CA',55},{'US-CO',9},{'US-CT',7},{'US-DE',3},{'US-FL',27},{'US-GA',15},{'US-HI',4},
  {'US-ID',4},{'US-IL',21},{'US-IN',11},{'US-IA',7},{'US-KS',6},{'US-KY',8},{'US-LA',9},{'US-ME',4},{'US-MD',10},{'US-MA',12},{'US-MI',17},
  {'US-MN',10},{'US-MS',6},{'US-MO',11},{'US-MT',3},{'US-NE',4},{'US-NV',5},{'US-NH',4},{'US-NJ',15},{'US-NM',5},{'US-NY',31},{'US-NC',15},
  {'US-ND',3},{'US-OH',20},{'US-OK',7},{'US-OR',7},{'US-PA',21},{'US-RI',4},{'US-SC',8},{'US-SD',3},{'US-TN',11},{'US-TX',34},{'US-UT',5},
  {'US-VT',3},{'US-VA',13},{'US-WA',11},{'US-WV',5},{'US-WI',10},{'US-WY',3},{'US-DC',3}
],{STRING iso_code;UNSIGNED c;});
ECStyle:=VL.Styles.SetValue(VL.Styles.Large,ChartAdvanced,'region:"US",resolution:"provinces",colorAxis:{minValue:0,colors:["#FFFFCC","#00FF00"]}');
VL.Google.Cartesian('GeoChart','ElectoralCollege',VL.FormatCartesianData(dElectoralCollege,iso_code),ECStyle);

dElected:=DATASET([
  {'US-AL',0},{'US-AK',0},{'US-AZ',0},{'US-AR',0},{'US-CA',1},{'US-CO',1},{'US-CT',1},{'US-DE',1},{'US-FL',1},{'US-GA',0},{'US-HI',1},
  {'US-ID',0},{'US-IL',1},{'US-IN',1},{'US-IA',1},{'US-KS',0},{'US-KY',0},{'US-LA',0},{'US-ME',1},{'US-MD',1},{'US-MA',1},{'US-MI',1},
  {'US-MN',1},{'US-MS',0},{'US-MO',0},{'US-MT',0},{'US-NE',0},{'US-NV',1},{'US-NH',1},{'US-NJ',1},{'US-NM',1},{'US-NY',1},{'US-NC',1},
  {'US-ND',0},{'US-OH',1},{'US-OK',0},{'US-OR',1},{'US-PA',1},{'US-RI',1},{'US-SC',0},{'US-SD',0},{'US-TN',0},{'US-TX',0},{'US-UT',0},
  {'US-VT',1},{'US-VA',1},{'US-WA',1},{'US-WV',0},{'US-WI',1},{'US-WY',0},{'US-DC',1}
],{STRING iso_code;UNSIGNED c;});
V2008Style:=VL.Styles.SetValue(VL.Styles.Large,ChartAdvanced,'region:"US",resolution:"provinces",colorAxis:{minValue:0,colors:["#FF0000","#0000FF"]}');
VL.Google.Cartesian('GeoChart','Results2008',VL.FormatCartesianData(dElected,iso_code),V2008Style);

