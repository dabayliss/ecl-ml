<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="html"/>
  <xsl:include href="D3_std.xslt"/>
  <xsl:include href="GOOGLE_std.xslt"/>

  <xsl:template match="/">
    <xsl:apply-templates select="*/Results/Result"/>
  </xsl:template>

  <xsl:template match="Result">
    <html>
      <head>
        <title>ECL Visualisation.</title>

        <script type="text/javascript" src="http://mbostock.github.com/d3/d3.js?2.4.6"></script>
        <style type="text/css">
          <xsl:text>
            @import url("http://mbostock.github.com/d3/style.css?1.10.0");
            @import url("http://mbostock.github.com/d3/syntax.css?1.6.0");
          </xsl:text>
        </style>

        <script type="text/javascript" src="http://www.google.com/jsapi"> </script>
        <script type="text/javascript"><xsl:text>
           google.load('visualization', '1.0', {packages: ['corechart', 'geochart', 'annotatedtimeline', 'table', 'motionchart', 'ImageSparkLine']});
          </xsl:text>
          <xsl:apply-templates select="Dataset" mode="generate_script"/>
        </script>
      </head>
      <body>
        <xsl:apply-templates select="Dataset" mode="generate_body"/>
      </body>
    </html>
  </xsl:template>

</xsl:stylesheet>