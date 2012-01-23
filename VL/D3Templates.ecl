EXPORT D3Templates:=MODULE

EXPORT STRING VoronoiDynamic(STRING chartname):=''+
  'var w=800;'+
  'var h=800;'+
  'max_w=0;'+
  'max_h=0;'+
  'for(i in vertices){for(j in vertices[i]){if(vertices[i][j][0]>max_w) max_w=vertices[i][j][0];if(vertices[i][j][1]>max_h) max_h=vertices[i][j][1];}}'+
  'for(i in documents){if(documents[i][0]>max_w) max_w=documents[i][0];if(documents[i][1]>max_h) max_h=documents[i][1];}'+
  'for(i in vertices){for(j in vertices[i]){vertices[i][j][0]=vertices[i][j][0]*(w/max_w);vertices[i][j][1]=vertices[i][j][1]*(h/max_h);}}'+
  'for(i in documents){documents[i][0]=documents[i][0]*(w/max_w);documents[i][1]=documents[i][1]*(h/max_h);}'+
  'var svg = d3.select("#'+chartname+'").append("svg:svg").attr("width", w).attr("height", h).attr("class", "Spectral").on("mousemove", update);'+
  'svg.selectAll("path").data(d3.geom.voronoi(vertices[0])).enter().append("svg:path").attr("class", function(d, i) { return "q" + (i % 11) + "-11"; }).attr("d", function(d) { return "M" + d.join("L") + "Z"; });'+
  'svg.selectAll("circle").data(vertices[0]).enter().append("svg:circle").attr("transform", function(d) { return "translate("+d+")"; }).attr("r", 7).style("fill", "steelblue");'+
  'svg.selectAll("rect").data(documents).enter().append("svg:rect").attr("transform", function(d) { return "translate(" + d + ")"; }).attr("width", 3).attr("height",3);'+
  'function update()'+
  '{'+
  'var h1 = Math.round((d3.svg.mouse(this)[1]/w)*vertices.length)-1;'+
  'svg.selectAll("path").data(d3.geom.voronoi(vertices[h1]).map(function(d) { return "M" + d.join("L") + "Z"; })).filter(function(d) { return this.getAttribute("d") != d; }).attr("d", function(d) { return d; });'+
  'svg.selectAll("circle").data(vertices[h1]).attr("transform",function(d) {return "translate("+d+")";}).attr("r", 7);'+
  '}';

END;