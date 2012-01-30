EXPORT D3Templates:=MODULE

EXPORT STRING VoronoiTesselation(STRING chartname):=''+
  'max_w=0;'+
  'max_h=0;'+
  'for(i in points){if(points[i][0]>max_w) max_w=points[i][0];if(points[i][1]>max_h) max_h=points[i][1];}'+
  'max_w+=margin;max_h+=margin;'+
  'for(i in points){points[i][0]=points[i][0]*(w/max_w);points[i][1]=points[i][1]*(h/max_h);}'+
  'var svg=d3.select("#'+chartname+'").append("svg:svg").attr("width",w).attr("height",h).attr("class","Spectral");'+
  'svg.selectAll("path").data(d3.geom.voronoi(points)).enter().append("svg:path").attr("class",function(d,i){ return "q"+(i%11)+"-11";}).attr("d",function(d){ return "M"+d.join("L")+"Z";});'+
  'svg.selectAll("circle").data(points).enter().append("svg:circle").attr("transform",function(d){return "translate("+d+")";}).attr("r",7).style("fill","steelblue");';

EXPORT STRING VoronoiDynamic(STRING chartname):=''+
  'max_w=0;'+
  'max_h=0;'+
  'for(i in centroids){for(j in centroids[i]){if(centroids[i][j][0]>max_w) max_w=centroids[i][j][0];if(centroids[i][j][1]>max_h) max_h=centroids[i][j][1];}}'+
  'for(i in documents){if(documents[i][0]>max_w) max_w=documents[i][0];if(documents[i][1]>max_h) max_h=documents[i][1];}'+
  'max_w+=margin;max_h+=margin;'+
  'for(i in centroids){for(j in centroids[i]){centroids[i][j][0]=centroids[i][j][0]*(w/max_w);centroids[i][j][1]=centroids[i][j][1]*(h/max_h);}}'+
  'for(i in documents){documents[i][0]=documents[i][0]*(w/max_w);documents[i][1]=documents[i][1]*(h/max_h);}'+
  'var svg = d3.select("#'+chartname+'").append("svg:svg").attr("width", w).attr("height", h).attr("class", "Spectral").on("mousemove", update);'+
  'svg.selectAll("path").data(d3.geom.voronoi(centroids[0])).enter().append("svg:path").attr("class", function(d, i) { return "q" + (i % 11) + "-11"; }).attr("d", function(d) { return "M" + d.join("L") + "Z"; });'+
  'svg.selectAll("circle").data(centroids[0]).enter().append("svg:circle").attr("transform", function(d) { return "translate("+d+")"; }).attr("r", 7).style("fill", "steelblue");'+
  'svg.selectAll("rect").data(documents).enter().append("svg:rect").attr("transform", function(d) { return "translate(" + d + ")"; }).attr("width", 3).attr("height",3);'+
  'function update()'+
  '{'+
  'var h1 = Math.round((d3.svg.mouse(this)[1]/w)*centroids.length)-1;'+
  'svg.selectAll("path").data(d3.geom.voronoi(centroids[h1]).map(function(d) { return "M" + d.join("L") + "Z"; })).filter(function(d) { return this.getAttribute("d") != d; }).attr("d", function(d) { return d; });'+
  'svg.selectAll("circle").data(centroids[h1]).attr("transform",function(d) {return "translate("+d+")";}).attr("r", 7);'+
  '}';

EXPORT STRING VoronoiStatic(STRING chartname):=''+
  'max_w=0;'+
  'max_h=0;'+
  'for(i in centroids){if(centroids[i][0]>max_w) max_w=centroids[i][0];if(centroids[i][1]>max_h) max_h=centroids[i][1];}'+
  'for(i in documents){if(documents[i][0]>max_w) max_w=documents[i][0];if(documents[i][1]>max_h) max_h=documents[i][1];}'+
  'max_w+=margin;max_h+=margin;'+
  'for(i in centroids){centroids[i][0]=centroids[i][0]*(w/max_w);centroids[i][1]=centroids[i][1]*(h/max_h);}'+
  'for(i in documents){documents[i][0]=documents[i][0]*(w/max_w);documents[i][1]=documents[i][1]*(h/max_h);}'+
  'var svg = d3.select("#'+chartname+'").append("svg:svg").attr("width", w).attr("height", h).attr("class", "Spectral");'+
  'svg.selectAll("path").data(d3.geom.voronoi(centroids)).enter().append("svg:path").attr("class", function(d, i) { return "q" + (i % 11) + "-11"; }).attr("d", function(d) { return "M" + d.join("L") + "Z"; });'+
  'svg.selectAll("circle").data(centroids).enter().append("svg:circle").attr("transform", function(d) { return "translate(" + d + ")"; }).attr("r", 7).style("fill", "steelblue");'+
  'svg.selectAll("rect").data(documents).enter().append("svg:rect").attr("transform", function(d) { return "translate(" + d + ")"; }).attr("width", 3).attr("height",3);';

END;