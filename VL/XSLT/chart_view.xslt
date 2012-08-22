<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="html" indent="yes"/>
  
  <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:template match="Dataset[starts-with(@name,'CHART_')]" mode="generate_body">
      <xsl:for-each select="Row[chartelementtype='CHARTCODE']">
        <xsl:value-of disable-output-escaping="yes" select="s"/>
      </xsl:for-each>
    </xsl:template>
  </xsl:stylesheet>

  <xsl:template match="/">
    <xsl:apply-templates select="*/Results/Result"/>
  </xsl:template>

  <xsl:template match="Result">
    <xsl:apply-templates select="Dataset" mode="generate_body"/>
  </xsl:template>

</xsl:stylesheet>