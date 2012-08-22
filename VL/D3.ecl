IMPORT Vl;
EXPORT D3:=MODULE

  //-------------------------------------------------------------------------
  // Tree template and function that takes the data from the standard graph
  // datasets and produces a tree structure using the following d3 example:
  //   http://mbostock.github.com/d3/talk/20111018/tree.html
  //-------------------------------------------------------------------------
  SHARED TreeTemplate(STRING sData):=''+
		'<html><head><meta http-equiv="Content-Type" content="text/html;charset=utf-8"/>'+
		'<link type="text/css" rel="stylesheet" href="http://mbostock.github.com/d3/style.css"/>'+
		'<script type="text/javascript" src="http://mbostock.github.com/d3/d3.js"></script>'+
		'<style type="text/css">'+
		'.node circle{cursor:pointer;fill:#fff;stroke:steelblue;stroke-width:1.5px;}'+
		'.node text{font-size:11px;}'+
		'path.link{fill:none;stroke:#ccc;stroke-width:1.5px;}'+
		'</style></head><body><div id="body"></div>'+
		'<script type="text/javascript">'+
		'var data ='+sData+';'+
		'var m=[20,120,20,120],w=1280-m[1]-m[3],h=700-m[0]-m[2],i=0;'+
		'var tree=d3.layout.tree().size([h, w]);'+
		'var diagonal=d3.svg.diagonal().projection(function(d){return [d.y,d.x];});'+
		'var vis=d3.select("#body").append("svg:svg").attr("width",w+m[1]+m[3]).attr("height",h+m[0]+m[2]).append("svg:g").attr("transform","translate("+m[3]+","+m[0]+")");'+
		'data.x0=h/2;data.y0=0;'+
		'function toggleAll(d){if (d.children){d.children.forEach(toggleAll);toggle(d);}};'+
		'data.children.forEach(toggleAll);'+
		'update(data);'+
		'function update(source){'+
		'var duration=d3.event && d3.event.altKey?5000:500;'+
		'var nodes=tree.nodes(data).reverse();'+
		'nodes.forEach(function(d) {d.y=d.depth*180;});'+
		'var node=vis.selectAll("g.node").data(nodes,function(d){ return d.id||(d.id=++i);});'+
		'var nodeEnter=node.enter().append("svg:g").attr("class","node").attr("transform",function(d){return "translate("+source.y0+","+source.x0+")";}).on("click",function(d){toggle(d);update(d);});'+
		'nodeEnter.append("svg:circle").attr("r",1e-6).style("fill",function(d){return d._children?"lightsteelblue":"#fff";});'+
		'nodeEnter.append("svg:text").attr("x",function(d){return d.children||d._children?-10:10;}).attr("dy",".35em").attr("text-anchor",function(d){return d.children||d._children?"end":"start";}).text(function(d){return d.name;}).style("fill-opacity",1e-6);'+
		'var nodeUpdate=node.transition().duration(duration).attr("transform",function(d){return "translate("+d.y+","+d.x+")";});'+
		'nodeUpdate.select("circle").attr("r",4.5).style("fill",function(d){return d._children?"lightsteelblue":"#fff";});'+
		'nodeUpdate.select("text").style("fill-opacity",1);'+
		'var nodeExit=node.exit().transition().duration(duration).attr("transform",function(d){return "translate("+source.y+","+source.x+")";}).remove();'+
		'nodeExit.select("circle").attr("r",1e-6);'+
		'nodeExit.select("text").style("fill-opacity",1e-6);'+
		'var link=vis.selectAll("path.link").data(tree.links(nodes),function(d){return d.target.id;});'+
		'link.enter().insert("svg:path","g").attr("class","link").attr("d",function(d){var o={x: source.x0,y:source.y0};return diagonal({source:o,target:o});}).transition().duration(duration).attr("d",diagonal);'+
		'link.transition().duration(duration).attr("d",diagonal);'+
		'link.exit().transition().duration(duration).attr("d",function(d){var o={x:source.x,y:source.y};return diagonal({source: o,target: o});}).remove();'+
		'nodes.forEach(function(d){d.x0=d.x;d.y0=d.y;});};'+
		'function toggle(d){if (d.children){d._children=d.children;d.children=null;}else{d.children=d._children;d._children=null;}};'+
		'</script></body></html>';
    
  SHARED STRING ConvertToTree(DATASET(VL.Types.GraphLabels) dLabels,DATASET(VL.Types.GraphRelationships) dRelationships):=FUNCTION
    dParentLabels:=JOIN(dRelationships,TABLE(dLabels,{id;STRING parent:=label;}),LEFT.id=RIGHT.id);
    dChildLabels:=JOIN(dParentLabels,TABLE(dLabels,{id;STRING child:=label;}),LEFT.linkid=RIGHT.id);
    dWithJson:=TABLE(dChildLabels,{dChildLabels;UNSIGNED level:=0;STRING json:='';});

    RECORDOF(dWithJson) tGetLevels(DATASET(RECORDOF(dWithJson)) d,UNSIGNED i):=FUNCTION
      dTop:=PROJECT(JOIN(d(level=0),d(level=0),LEFT.id=RIGHT.linkid,TRANSFORM(LEFT),LEFT ONLY),TRANSFORM(RECORDOF(LEFT),SELF.level:=i;SELF:=LEFT;));
      RETURN IF(COUNT(d(level=0))=0,d,d(level>0)+dTop+JOIN(d(level=0),dTop,LEFT.id=RIGHT.id,LEFT ONLY));
    END;
    dWithLevels:=LOOP(dWithJson,100,tGetLevels(ROWS(LEFT),COUNTER));
    
    iLowestLevel:=MAX(dWithLevels,level);
    RECORDOF(dWithLevels) tConstructJson(DATASET(RECORDOF(dWithLevels)) d,UNSIGNED i):=FUNCTION
      dLowest:=PROJECT(d(level=i),TRANSFORM(RECORDOF(LEFT),SELF.json:=IF(LEFT.json='','{"name":"'+LEFT.child+'"}',LEFT.json);SELF:=LEFT;));
      dRolled:=ROLLUP(SORT(dLowest,id),LEFT.id=RIGHT.id,TRANSFORM(RECORDOF(LEFT),SELF.json:=LEFT.json+','+RIGHT.json;SELF:=LEFT;));
      dJoined:=JOIN(d(level<i),dRolled,LEFT.linkid=RIGHT.id,TRANSFORM(RECORDOF(LEFT),SELF.json:=IF(RIGHT.json='','','{"name":"'+LEFT.child+'","children":['+RIGHT.json+']}');SELF:=LEFT;),LEFT OUTER);
      dFinal:=PROJECT(dRolled,TRANSFORM(RECORDOF(LEFT),SELF.json:='{"name":"'+LEFT.parent+'","children":['+LEFT.json+']}';SELF:=LEFT;));
      RETURN IF(COUNT(dRolled)=1,dFinal,dJoined);
    END;
    dJson:=LOOP(dWithLevels,iLowestLevel,tConstructJson(ROWS(LEFT),iLowestLevel-COUNTER+1));
    RETURN dJson[1].json;
  END;
    
  //-------------------------------------------------------------------------
  // Constructs a chord diagram from the data in graph dataset format as in
  // the following d3 example:
  //   http://mbostock.github.com/d3/ex/chord.html
  //-------------------------------------------------------------------------
  SHARED ChordTemplate(STRING sData):=''+
		'<!DOCTYPE html>'+
		'<style>@import url(http://mbostock.github.com/d3/style.css?20120427);'+
		'#circle circle {fill: none;pointer-events: all;}'+
		'.group path {fill-opacity: .5;}'+
		'path.chord {stroke: #000;stroke-width: .25px;}'+
		'#circle:hover path.fade {display: none;}'+
		'</style>'+
		'<h1>Chord</h1>'+
		'<script src="http://d3js.org/d3.v2.min.js?2.8.1"></script>'+
		'<script>'+
		'var width = 700,height = 700,outerRadius = Math.min(width, height) / 2 - 10,innerRadius = outerRadius - 24;'+
		'var formatPercent = d3.format(".1%");'+
		'var arc = d3.svg.arc().innerRadius(innerRadius).outerRadius(outerRadius);'+
		'var layout = d3.layout.chord().padding(.04).sortSubgroups(d3.descending).sortChords(d3.ascending);'+
		'var path = d3.svg.chord().radius(innerRadius);'+
		'var svg = d3.select("body").append("svg").attr("width", width).attr("height", height).append("g").attr("id", "circle").attr("transform", "translate(" + width / 2 + "," + height / 2 + ")");'+
		'svg.append("circle").attr("r", outerRadius);'+
		'var colors=["rgb(158,1,66)","rgb(213,62,79)","rgb(244,109,67)","rgb(253,174,97)","rgb(254,224,139)","rgb(255,255,191)","rgb(230,245,152)","rgb(171,221,164)","rgb(102,194,165)","rgb(50,136,189)","rgb(94,79,162)"];'+
		sData+
    'layout.matrix(matrix);'+
		'var group = svg.selectAll(".group").data(layout.groups).enter().append("g").attr("class", "group").on("mouseover", mouseover);group.append("title").text(function(d, i) {return categories[i].name + ": " + formatPercent(d.value) + " of origins";});'+
		'var groupPath = group.append("path").attr("id", function(d, i) { return "group" + i; }).attr("d", arc).style("fill", function(d, i) { return colors[i%11];});'+
		'var groupText = group.append("text").attr("x", 6).attr("dy", 15);'+
		'groupText.append("textPath").attr("xlink:href", function(d, i) { return "#group" + i; }).text(function(d, i) { return categories[i].name; });'+
		'groupText.filter(function(d, i) { return groupPath[0][i].getTotalLength() / 2 - 16 < this.getComputedTextLength(); }).remove();'+
		'var chord = svg.selectAll(".chord").data(layout.chords).enter().append("path").attr("class", "chord").style("fill", function(d) { return colors[d.source.index%11]; }).attr("d", path);'+
		'chord.append("title").text(function(d){return categories[d.source.index].name+"->"+categories[d.target.index].name+": "+formatPercent(d.source.value)+"\\n"+categories[d.target.index].name+"->"+categories[d.source.index].name+": "+formatPercent(d.target.value);});'+
		'function mouseover(d, i) {chord.classed("fade", function(p) {return p.source.index!=i && p.target.index != i;});};</script>';
    
  SHARED STRING ConvertToChord(DATASET(VL.Types.GraphLabels) dLabels,DATASET(VL.Types.GraphRelationships) dRelationships):=FUNCTION
    dLReSequenced:=PROJECT(dLabels,TRANSFORM({RECORDOF(LEFT);UNSIGNED oldid;},SELF.oldid:=LEFT.id;SELF.id:=COUNTER;SELF:=LEFT;));
    dR01:=JOIN(dRelationships,dLReSequenced,LEFT.id=RIGHT.oldid,TRANSFORM(RECORDOF(LEFT),SELF.id:=RIGHT.id;SELF:=LEFT;));
    dRReSequenced:=JOIN(dR01,dLReSequenced,LEFT.linkid=RIGHT.oldid,TRANSFORM(RECORDOF(LEFT),SELF.linkid:=RIGHT.id;SELF:=LEFT;));
    
    dLabelPrep:=PROJECT(dLReSequenced,TRANSFORM(RECORDOF(LEFT),SELF.label:='{"name":"'+LEFT.label+'"}';SELF:=LEFT;));
    dLabelRolled:=ROLLUP(dLabelPrep,LEFT.id!=RIGHT.id,TRANSFORM(RECORDOF(LEFT),SELF.label:=LEFT.label+','+RIGHT.label;SELF:=[];));
    
    dAllPossibles:=JOIN(dLReSequenced,dLReSequenced,TRUE,TRANSFORM({UNSIGNED id;UNSIGNED linkid;},SELF.id:=LEFT.id;SELF.linkid:=RIGHT.id;),ALL);
    dInterractions:=JOIN(dAllPossibles,dRReSequenced,LEFT.id=RIGHT.id AND LEFT.linkid=RIGHT.linkid,TRANSFORM({RECORDOF(LEFT);REAL weight;},SELF.weight:=IF(RIGHT.id=0,0,IF(RIGHT.weight=0,1,RIGHT.weight));SELF:=LEFT;),LEFT OUTER);
    nTotal:=SUM(dInterractions,weight);
    dPercentages:=PROJECT(dInterractions,TRANSFORM({RECORDOF(LEFT);STRING matrix;},SELF.matrix:=(STRING)(LEFT.weight/nTotal);SELF:=LEFT;));
    dRoll01:=ROLLUP(dPercentages,LEFT.id=RIGHT.id,TRANSFORM(RECORDOF(LEFT),SELF.matrix:=LEFT.matrix+','+RIGHT.matrix;SELF:=LEFT;));
    dRoll02:=ROLLUP(PROJECT(dRoll01,TRANSFORM(RECORDOF(LEFT),SELF.matrix:='['+LEFT.matrix+']';SELF:=LEFT)),LEFT.id!=RIGHT.id,TRANSFORM(RECORDOF(LEFT),SELF.matrix:=LEFT.matrix+','+RIGHT.matrix;SELF:=[];));
    RETURN 'var categories=['+dLabelRolled[1].label+'];var matrix=['+dRoll02[1].matrix+'];';
  END;
  
  // Primary function to call to produce D3 charts.
  EXPORT Graph(STRING sChartType,STRING sChartName,DATASET(VL.Types.GraphLabels) dLabels,DATASET(VL.Types.GraphRelationships) dRelationships,VL.Styles.Default s=VL.Styles.Default):=FUNCTION
    RETURN MAP(
      sChartType='Tree'=>OUTPUT(DATASET([{'CHARTCODE',TreeTemplate(ConvertToTree(dLabels,dRelationships))}],VL.Types.ChartInterface),NAMED('CHART_'+sChartName)),
      sChartType='Chord'=>OUTPUT(DATASET([{'CHARTCODE',ChordTemplate(ConvertToChord(dLabels,dRelationships))}],VL.Types.ChartInterface),NAMED('CHART_'+sChartName)),
      OUTPUT('Blah')
    );
  END;
END;