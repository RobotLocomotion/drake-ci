<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:date="http://exslt.org/dates-and-times" version="1.0">
  <xsl:output method="xml" indent="yes"/>
  <xsl:template match="/Site">
    <xsl:variable name="TestSuiteName">
      <xsl:value-of select="@Name"/>
    </xsl:variable>
    <xsl:variable name="TestSuiteHostName">
      <xsl:value-of select="@Hostname"/>
    </xsl:variable>
    <xsl:variable name="TestSuiteTests">
      <xsl:value-of select="count(//TestList/Test)"/>
    </xsl:variable>
    <xsl:variable name="TestSuiteFailures">
      <xsl:value-of select="count(//Testing/Test[@Status='failed'])"/>
    </xsl:variable>
    <xsl:variable name="TestSuiteTime">
      <xsl:value-of select="Testing/EndTestTime - Testing/StartTestTime"/>
    </xsl:variable>
    <xsl:variable name="TestSuiteTimeStamp">
      <xsl:value-of select="date:add('1970-01-01T00:00:00Z', date:duration(Testing/StartTestTime))"/>
    </xsl:variable>
    <testsuite name="{$TestSuiteName}" hostname="{$TestSuiteHostName}" errors="0" failures="{$TestSuiteFailures}" tests="{$TestSuiteTests}" time="{$TestSuiteTime}" timestamp="{$TestSuiteTimeStamp}">
      <xsl:variable name="BuildName">
        <xsl:value-of select="@BuildName"/>
      </xsl:variable>
      <xsl:variable name="BuildStamp">
        <xsl:value-of select="@BuildStamp"/>
      </xsl:variable>
      <xsl:variable name="Generator">
        <xsl:value-of select="@Generator"/>
      </xsl:variable>
      <xsl:variable name="CompilerName">
        <xsl:value-of select="@CompilerName"/>
      </xsl:variable>
      <xsl:variable name="CompilerVersion">
        <xsl:value-of select="@CompilerVersion"/>
      </xsl:variable>
      <xsl:variable name="OSName">
        <xsl:value-of select="@OSName"/>
      </xsl:variable>
      <xsl:variable name="OSRelease">
        <xsl:value-of select="@OSRelease"/>
      </xsl:variable>
      <xsl:variable name="OSVersion">
        <xsl:value-of select="@OSVersion"/>
      </xsl:variable>
      <xsl:variable name="OSPlatform">
        <xsl:value-of select="@OSPlatform"/>
      </xsl:variable>
      <xsl:variable name="Is64Bits">
        <xsl:value-of select="@Is64Bits"/>
      </xsl:variable>
      <xsl:variable name="VendorString">
        <xsl:value-of select="@VendorString"/>
      </xsl:variable>
      <xsl:variable name="VendorID">
        <xsl:value-of select="@VendorID"/>
      </xsl:variable>
      <xsl:variable name="FamilyID">
        <xsl:value-of select="@FamilyID"/>
      </xsl:variable>
      <xsl:variable name="ModelID">
        <xsl:value-of select="@ModelID"/>
      </xsl:variable>
      <xsl:variable name="ProcessorCacheSize">
        <xsl:value-of select="@ProcessorCacheSize"/>
      </xsl:variable>
      <xsl:variable name="NumberOfLogicalCPU">
        <xsl:value-of select="@NumberOfLogicalCPU"/>
      </xsl:variable>
      <xsl:variable name="NumberOfPhysicalCPU">
        <xsl:value-of select="@NumberOfPhysicalCPU"/>
      </xsl:variable>
      <xsl:variable name="TotalVirtualMemory">
        <xsl:value-of select="@TotalVirtualMemory"/>
      </xsl:variable>
      <xsl:variable name="TotalPhysicalMemory">
        <xsl:value-of select="@TotalPhysicalMemory"/>
      </xsl:variable>
      <xsl:variable name="LogicalProcessorsPerPhysical">
        <xsl:value-of select="@LogicalProcessorsPerPhysical"/>
      </xsl:variable>
      <xsl:variable name="ProcessorClockFrequency">
        <xsl:value-of select="@ProcessorClockFrequency"/>
      </xsl:variable>
      <properties>
        <property name="BuildName" value="{$BuildName}"/>
        <property name="BuildStamp" value="{$BuildStamp}"/>
        <property name="Generator" value="{$Generator}"/>
        <property name="CompilerName" value="{$CompilerName}"/>
        <property name="CompilerVersion" value="{$CompilerVersion}"/>
        <property name="OSName" value="{$OSName}"/>
        <property name="OSRelease" value="{$OSRelease}"/>
        <property name="OSVersion" value="{$OSVersion}"/>
        <property name="OSPlatform" value="{$OSPlatform}"/>
        <property name="Is64Bits" value="{$Is64Bits}"/>
        <property name="VendorString" value="{$VendorString}"/>
        <property name="VendorID" value="{$VendorID}"/>
        <property name="FamilyID" value="{$FamilyID}"/>
        <property name="ModelID" value="{$ModelID}"/>
        <property name="ProcessorCacheSize" value="{$ProcessorCacheSize}"/>
        <property name="NumberOfLogicalCPU" value="{$NumberOfLogicalCPU}"/>
        <property name="NumberOfPhysicalCPU" value="{$NumberOfPhysicalCPU}"/>
        <property name="TotalVirtualMemory" value="{$TotalVirtualMemory}"/>
        <property name="TotalPhysicalMemory" value="{$TotalPhysicalMemory}"/>
        <property name="LogicalProcessorsPerPhysical" value="{$LogicalProcessorsPerPhysical}"/>
        <property name="ProcessorClockFrequency" value="{$ProcessorClockFrequency}"/>
      </properties>
      <xsl:apply-templates select="Testing/Test"/>
    </testsuite>
  </xsl:template>
  <xsl:template match="Testing/Test">
    <xsl:variable name="TestCaseName">
       <xsl:value-of select="Name"/>
    </xsl:variable>
    <xsl:variable name="TestCaseClassName">
      <xsl:value-of select="substring(Path,2)"/>
    </xsl:variable>
    <xsl:variable name="TestCaseTime">
      <xsl:for-each select="Results/NamedMeasurement">
        <xsl:if test="@name = 'Execution Time'">
          <xsl:value-of select="Value"/>
        </xsl:if>
      </xsl:for-each>
    </xsl:variable>
    <testcase name="{$TestCaseName}" classname="{$TestCaseClassName}" time="{$TestCaseTime}">
      <xsl:if test="@Status = 'passed'"/>
      <xsl:if test="@Status = 'failed'">
        <xsl:variable name="TestCaseExitCode">
          <xsl:for-each select="Results/NamedMeasurement">
            <xsl:if test="@name = 'Exit Code'">
              <xsl:value-of select="Value"/>
            </xsl:if>
          </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="TestCaseExitValue">
          <xsl:for-each select="Results/NamedMeasurement">
            <xsl:if test="@name = 'Exit Value'">
              <xsl:value-of select="Value"/>
            </xsl:if>
          </xsl:for-each>
        </xsl:variable>
        <failure message="{$TestCaseExitCode} ({$TestCaseExitValue})"><xsl:value-of select="Results/Measurement/Value/text()"/></failure>
      </xsl:if>
      <xsl:if test="@Status = 'notrun'">
        <skipped><xsl:value-of select="Results/Measurement/Value/text()"/></skipped>
      </xsl:if>
    </testcase>
  </xsl:template>
</xsl:stylesheet>
