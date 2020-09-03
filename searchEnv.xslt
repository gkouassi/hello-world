<?xml version="1.0" encoding="ISO-8859-1" ?>
 
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns="http://www.w3.org/1999/xhtml">
 
   <xsl:output method="text" encoding="ISO-8859-1"/>
 
   
    <xsl:param name="tibco_env"/> 

    <xsl:template match="/TIBCOEnvironment/environment[@location = $tibco_env]">
          name=<xsl:value-of select="@name"/>
configDir=<xsl:value-of select="@configDir"/>
    </xsl:template>  
 </xsl:stylesheet>
