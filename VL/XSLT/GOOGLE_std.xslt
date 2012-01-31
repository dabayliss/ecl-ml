<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="Dataset[starts-with(@name,'GOOGLEStd')]" mode="generate_body">
  <div>
    <xsl:attribute name="id"><xsl:value-of select="@name"/></xsl:attribute>
  </div>
  </xsl:template>

  <xsl:template match="Dataset[starts-with(@name,'GOOGLEStd')]" mode="generate_script">
      <xsl:text>
      google.setOnLoadCallback(draw</xsl:text><xsl:value-of select="@name"/><xsl:text>);
      function draw</xsl:text><xsl:value-of select="@name"/><xsl:text>()
      {
</xsl:text>
//---------------------------------------------------------------------------
// DATA PASTED HERE
//---------------------------------------------------------------------------
 <xsl:for-each select="Row[chartelementtype='DATA']">
     <xsl:value-of select="s"/>
 </xsl:for-each>
//---------------------------------------------------------------------------
// OPTIONS PASTED HERE
//---------------------------------------------------------------------------
 <xsl:for-each select="Row[chartelementtype='OPTIONS']">
     <xsl:value-of select="s"/>
 </xsl:for-each>
//---------------------------------------------------------------------------
// CHART DRAW CALL PASTED HERE
//---------------------------------------------------------------------------
 <xsl:for-each select="Row[chartelementtype='CHARTCALL']">
     <xsl:value-of select="s"/>
 </xsl:for-each>
//---------------------------------------------------------------------------
      <xsl:text>
      }
      </xsl:text>
  </xsl:template>
</xsl:stylesheet>