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

END;