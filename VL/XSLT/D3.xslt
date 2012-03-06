<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="Dataset[starts-with(@name,'D3CHART')]" mode="generate_styles">
    <xsl:for-each select="Row[chartelementtype='STYLES']">
     <xsl:value-of select="s"/>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="Dataset[starts-with(@name,'D3CHART')]" mode="generate_body">

  <div class="body">
    <div class="content">
       <div class='gallery'>
           <xsl:attribute name="id"><xsl:value-of select="@name"/></xsl:attribute>
       </div>
       <link href='http://mbostock.github.com/d3/ex/colorbrewer.css' rel='stylesheet' type='text/css' />
       <link href='http://mbostock.github.com/d3/ex/voronoi.css' rel='stylesheet' type='text/css' />
       <script src='http://mbostock.github.com/d3/d3.geom.js?2.4.6' type='text/javascript'></script>
       <script type='text/javascript'>

// Default values for width, height and margin
var w = 800;
var h = 600;
var margin=3;

//---------------------------------------------------------------------------
// OPTIONS PASTED HERE
//---------------------------------------------------------------------------
 <xsl:for-each select="Row[chartelementtype='OPTIONS']">
     <xsl:value-of select="s"/>
 </xsl:for-each>
//---------------------------------------------------------------------------
// DATA PASTED HERE
//---------------------------------------------------------------------------
 <xsl:for-each select="Row[chartelementtype='DATA']">
     <xsl:value-of select="s"/>
 </xsl:for-each>
//---------------------------------------------------------------------------
// CHART DRAW CALL PASTED HERE
//---------------------------------------------------------------------------
 <xsl:for-each select="Row[chartelementtype='CHARTCALL']">
     <xsl:value-of select="s"/>
 </xsl:for-each>
//---------------------------------------------------------------------------

      </script>
    </div>
  </div>

  </xsl:template>
  
  <xsl:template match="Dataset[starts-with(@name,'D3CHART')]" mode="generate_script">
  </xsl:template>

</xsl:stylesheet>