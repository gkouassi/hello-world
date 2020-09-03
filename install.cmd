@echo off
SETLOCAL EnableDelayedExpansion EnableExtensions
:: ---------------------------------------------
::      TIBCO BW6 Installation scripts
:: 		Author : FX Brun
:: ----------------------------------------------
cls

:: Resolve path
set DIRNAME=.\
if "%OS%" == "Windows_NT" set DIRNAME=%~dp0%
pushd "%DIRNAME%"
set SCRIPT_HOME=%CD%
set SCRIPT_HOME=%SCRIPT_HOME:"=%
popd

:: TIBCO HOME
set TIBCO_ROOT=%1%
if [%TIBCO_ROOT%] == [] (
	call :usage
	goto :EOF
)
set TIBCO_ROOT=%TIBCO_ROOT:"=%

:: BIN HOME
set BIN_HOME=%2%
if [%BIN_HOME%] == [] (
	call :usage
	goto :EOF
)
set BIN_HOME=%BIN_HOME:"=%


:: INSTALL_MAPPING
set INSTALL_MAPPING=%3%
if [%INSTALL_MAPPING%] == [] (
	call :usage
	goto :EOF
)
set INSTALL_MAPPING=%BIN_HOME%\common\fileInfos\%INSTALL_MAPPING%
set INSTALL_MAPPING=%INSTALL_MAPPING:"=%

::resolve
pushd "%BIN_HOME%"
set BIN_HOME=%CD%
popd

if NOT EXIST "%BIN_HOME%\extensions" (
	echo Binaries not found at %BIN_HOME%\extensions
	call :usage
	goto :EOF
)

if NOT EXIST "%INSTALL_MAPPING%" (
	echo Mapping file not found at %INSTALL_MAPPING%
	call :usage
	goto :EOF
)

::  Set temp dir
set TMP_DIR=%TIBCO_ROOT%\tmp\SOFT

set REALHOMEPATH=
for /f "delims=" %%a in ('cscript /nologo  "%SCRIPT_HOME%"\vbs\getHomeUser.vbs') do set REALHOMEPATH=%%a
if ["%REALHOMEPATH%"] == [""] (
	echo REAL HOME PATH not found
	exit /B 1
)

::Option to force re-installation
if "%4%" == "-force" set FORCE=true

:: init default
for /F %%i in ("%TIBCO_ROOT%") do set TIBCO_ENVNAME=%%~ni
set TIBCO_ENVNAME=%USERNAME%-%TIBCO_ENVNAME%
set TIBCO_ENV_INFOS=%REALHOMEPATH%\.TIBCOEnvInfo\_envInfo.xml
set TIBCO_CONFIG_DIR=%TIBCO_ROOT%\config\tibco
set TIBCO_EMS_CONFIG_DIR=%TIBCO_CONFIG_DIR%\cfgmgmt\ems\data
set TIBCO_EMS_CONFIG_FILE=%TIBCO_EMS_CONFIG_DIR%\tibemsd.conf
set SOFT_MONITOR_ROOT=%TIBCO_ROOT%\soft\monitor
set SOFT_MDA_ROOT=%TIBCO_ROOT%\soft\mda
set SOFT_BW6_DEPLOYER_ROOT=%TIBCO_ROOT%\soft\deployer

::init create env
set TIBCO_CREATE_NEW_ENV=true

::TIBINSTALLER_CMD
set TIBINSTALLER_CMD=TIBCOUniversalInstaller.cmd

::find processor architecture
set arch64=
for /F %%a in ('echo %PROCESSOR_ARCHITECTURE%^|FINDSTR 64') do set arch64=%%a
if not [%arch64%] == [] (
	set BINVERSION=windows64
	set TIBINSTALLER=TIBCOUniversalInstaller-x86-64.exe
) else (
	set BINVERSION=windows
	set TIBINSTALLER=TIBCOUniversalInstaller.exe
)

::LGPL
set LGPLAssemblyPath=%BIN_HOME%\%BINVERSION%\lgpl
::ThirdParties dependencies
set ThirdPartiesPath=%BIN_HOME%\%BINVERSION%\thirdparties

:: Fixed file name
set installFileName=tibco-installation.properties
set installFile=%REALHOMEPATH%\%installFileName%

ECHO.
ECHO ------------------------------------------------------
ECHO Start install binairies at : %Date% %Time%
ECHO ------------------------------------------------------

echo User home is %REALHOMEPATH%
echo EnvName is %TIBCO_ENVNAME%
echo.

:: For previous installer versions
call :cleanupPreviousInstaller

:: Copy unzip
IF NOT EXIST "%SystemRoot%\unzip.exe" (
	copy /Y "%BIN_HOME%"\common\unzip\unzip.exe "%SystemRoot%"
)

call :binaries
IF NOT %ERRORLEVEL% == 0 (
	echo error occurred
	goto end
)

call :hotfixes
IF NOT %ERRORLEVEL% == 0 (
	echo error occurred
	goto end
)

call :jdbc
IF NOT %ERRORLEVEL% == 0 (
	echo error occurred
	goto end
)

call :EMSPLUGIN
IF NOT %ERRORLEVEL% == 0 (
	echo error occurred
	goto end
)

call :softmonitor
IF NOT %ERRORLEVEL% == 0 (
	echo error occurred
	goto end
)

call :softmda
IF NOT %ERRORLEVEL% == 0 (
	echo error occurred
	goto end
)

call :softdeployer
IF NOT %ERRORLEVEL% == 0 (
	echo error occurred
	goto end
)

call :softplugins
IF NOT %ERRORLEVEL% == 0 (
	echo error occurred
	goto end
)

call :softbundles
IF NOT %ERRORLEVEL% == 0 (
	echo error occurred
	goto end
)


call :createInstallFile
IF NOT %ERRORLEVEL% == 0 (
	echo error occurred
	goto end
)

::Disable windows services
call :disableWindowsService


::Correct TRA bug
IF EXIST "%TIBCO_ROOT%\.installerregistrylock" (
	del /F "%TIBCO_ROOT%\.installerregistrylock"
	echo %TIBCO_ROOT%\.installerregistrylock Removed
)


goto end

:: -------------- usage ----------------------------
:usage
echo usage is       : install_bw6.cmd [TIBCO_ROOT] [BIN_HOME] [FILE_MAPPING] [-force], where 
echo TIBCO_ROOT     : TIBCO target directory 
echo BIN_HOME       : Source Directory where are installation files
echo FILE_MAPPING   : Intall mapping file name under %BIN_HOME%\common\fileInfos directory
echo -force         : Force re-installation, optionnal
goto :EOF

:: -------------- binaries ----------------------------
:binaries
for %%F in ("%BIN_HOME%"\%BINVERSION%\*.*) do (
	call :cleanupPreviousInstaller	
	if "%%~xF" == ".zip" call :installArchive "%%F" "%BIN_HOME%\%BINVERSION%\%%~nF" "%%~nF"	
	IF NOT !ERRORLEVEL! == 0 (
		exit /B !ERRORLEVEL!
	)
)
goto :EOF

:: -------------- hotfixes ----------------------------
:hotfixes
for %%F in ("%BIN_HOME%"\%BINVERSION%\hotfixes\*.zip) do (
	call :installArchive "%%F" "%BIN_HOME%\%BINVERSION%\hotfixes\%%~nF" "%%~nF"
	IF NOT !ERRORLEVEL! == 0 (
		exit /B !ERRORLEVEL!
	)
)
goto :EOF



:: -------------- jdbc ----------------------------
:jdbc
ECHO.
ECHO Installing JDBC drivers

::install
if not exist "%BIN_HOME%\extensions\jdbc" goto :EOF

::installing
call "%BIN_HOME%"\extensions\jdbc\install-bw6.cmd "%TIBCO_ROOT%"
IF NOT !ERRORLEVEL! == 0 (
	exit /B !ERRORLEVEL!
)

goto :EOF


:: -------------- EMS Plugin ----------------------------
:EMSPLUGIN
ECHO.
ECHO Installing EMS driver

::Local vars
SETLOCAL

::EMS
set EMS_PLUGIN=%TIBCO_ROOT%\components\shared\1.0.0\plugins

::install
if not exist "%EMS_PLUGIN%" goto :EOF

:: Find last bw versions & java
call :locateBWJava
if ["!BW_VERSION!"] == [""] goto :EOF

::bwinstall
set BWINSTALLCMD=%TIBCO_ROOT%\bw\!BW_VERSION!\bin\bwinstall
set BWINSTALLEMS=%TIBCO_ROOT%\bw\!BW_VERSION!\config\drivers\shells\ems.runtime

::test install
if not exist "%BWINSTALLEMS%" goto :EOF

:: answer
set ANSWERTMP=%TMP%\emsplugin.txt
echo %EMS_PLUGIN%> "%ANSWERTMP%"

:: install
cd %TIBCO_ROOT%\bw\!BW_VERSION!\bin
"%BWINSTALLCMD%" ems-driver < "%ANSWERTMP%"
del %ANSWERTMP%

ENDLOCAL
goto :EOF

:: -------------- SOFT MONITOR ----------------------------
:softmonitor
:: Find last versions
for %%F in ("%BIN_HOME%"\extensions\softmonitor\*.zip) do (
	call :installSOFTMonitor "%%~nF" "%%F"
	IF NOT !ERRORLEVEL! == 0 (
		exit /B !ERRORLEVEL!
	)
)
goto :EOF

:: -------------- SOFT MDA ----------------------------
:softmda
:: Find last versions
for %%F in ("%BIN_HOME%"\extensions\softmda\*.zip) do (
	call :installSOFTApps "%%~nF" "%%F" SOFTMda "%SOFT_MDA_ROOT%" "install.cmd"
	IF NOT !ERRORLEVEL! == 0 (
		echo !ERRORLEVEL!
		exit /B !ERRORLEVEL!
	)
)

goto :EOF


:: -------------- SOFT BW6Deployer ----------------------------
:softdeployer
:: Find last versions
for %%F in ("%BIN_HOME%"\extensions\softdeployer\*.zip) do (
	call :installSOFTApps "%%~nF" "%%F" SOFTBW6Deployer "%SOFT_BW6_DEPLOYER_ROOT%" "install\install.cmd"
	IF NOT !ERRORLEVEL! == 0 (
		echo !ERRORLEVEL!
		exit /B !ERRORLEVEL!
	)
)

goto :EOF

:: -------------- Plugins ----------------------------
:softplugins
:: Find last versions
for %%F in ("%BIN_HOME%"\extensions\plugins\*.zip) do (
	call :installPlugins "%%~nF" "%%F"
	IF NOT !ERRORLEVEL! == 0 (
		echo !ERRORLEVEL!
		exit /B !ERRORLEVEL!
	)
)
goto :EOF


:: -------------- Bundles ----------------------------
:softbundles
:: Find last versions
for %%F in ("%BIN_HOME%"\extensions\plugins\bundle\*.jar) do (
	call :installBundle "%%~nF" "%%F"
	IF NOT !ERRORLEVEL! == 0 (
		echo !ERRORLEVEL!
		exit /B !ERRORLEVEL!
	)
)
goto :EOF

:: -------------- createInstallFile ----------------------------
:createInstallFile
echo.
ECHO ------------------------------------------------------
echo Creating installation file : "%installFile%"

call :readInstallInfos
IF NOT %ERRORLEVEL% == 0 (
	echo error occurred
	call :Cleanup %extractedArchiveDir%
	exit /B %ERRORLEVEL%
)

::Local vars
SETLOCAL

:: Find last bw versions & java
call :locateBWJava

:: find ems version
call :locateEMSDir

::find jdbc dir
if NOT ["%BW_VERSION%"] == [""] (
	set TIBCO_BW_SYSTEM_DIR=%TIBCO_ROOT%\bw\!BW_VERSION!\system
	set TIBCO_BW_SYSTEM_LIB_DIR=!TIBCO_BW_SYSTEM_DIR!\lib
)
	
:: find tea version
for /f %%D in ('cscript /nologo "%SCRIPT_HOME%"\vbs\dir.vbs "%TIBCO_ROOT%"\tea') DO (
	if EXIST "%TIBCO_ROOT%"\tea\%%D\bin\tea.exe set TEA_VERSION=%%D
)
if NOT ["%TEA_VERSION%"] == [""] (
	set TIBCO_TEA_DIR=%TIBCO_ROOT%\tea\%TEA_VERSION%
)

:: find tea-ems-agent version
for /f %%D in ('cscript /nologo "%SCRIPT_HOME%"\vbs\dir.vbs "%TIBCO_ROOT%"\tea\agents\ems') DO (
	if EXIST "%TIBCO_ROOT%"\tea\agents\ems\%%D\bin\ems-agent.exe set TEA_EMS_AGENT_VERSION=%%D
)
if NOT ["%TEA_EMS_AGENT_VERSION%"] == [""] (
	set TIBCO_TEA_EMS_AGENT_DIR=%TIBCO_ROOT%\tea\agents\ems\%TEA_EMS_AGENT_VERSION%
)

:: find tea-hawk-agent version
for /f %%D in ('cscript /nologo "%SCRIPT_HOME%"\vbs\dir.vbs "%TIBCO_ROOT%"\tea\agents\hawk') DO (
	if EXIST "%TIBCO_ROOT%"\tea\agents\hawk\%%D\bin\tibhawkteaagent.exe set TEA_HAWK_AGENT_VERSION=%%D
)
if NOT ["%TEA_HAWK_AGENT_VERSION%"] == [""] (
	set TIBCO_HAWK_TEA_AGENT_DIR=%TIBCO_ROOT%\tea\agents\hawk\%TEA_HAWK_AGENT_VERSION%
)

:: find hawk version
for /f %%D in ('cscript /nologo "%SCRIPT_HOME%"\vbs\dir.vbs "%TIBCO_ROOT%"\hawk') DO (
	if EXIST "%TIBCO_ROOT%"\hawk\%%D\bin\tibhawkhma.exe set HAWK_VERSION=%%D
)
if NOT ["%HAWK_VERSION%"] == [""] (
	set TIBCO_HAWK_DIR=%TIBCO_ROOT%\hawk\%HAWK_VERSION%
	set TIBCO_HAWK_CONFIG_DIR=%TIBCO_CONFIG_DIR%\cfgmgmt\hawk
)



:: find tibrv version
for /f %%D in ('cscript /nologo "%SCRIPT_HOME%"\vbs\dir.vbs "%TIBCO_ROOT%"\tibrv') DO (
	if EXIST "%TIBCO_ROOT%"\tibrv\%%D\bin\rvd.exe set TIBRV_VERSION=%%D
)
if NOT ["%TIBRV_VERSION%"] == [""] (
	set TIBCO_RV_DIR=%TIBCO_ROOT%\tibrv\%TIBRV_VERSION%
)

:: find as version
for /f %%D in ('cscript /nologo "%SCRIPT_HOME%"\vbs\dir.vbs "%TIBCO_ROOT%"\as') DO (
	if EXIST "%TIBCO_ROOT%"\as\%%D\lib\as-common.jar set AS_VERSION=%%D
)
if NOT ["%AS_VERSION%"] == [""] (
	set TIBCO_AS_DIR=%TIBCO_ROOT%\as\%AS_VERSION%
)

:: find SOFTMonitor version
for /f %%D in ('cscript /nologo "%SCRIPT_HOME%"\vbs\dir.vbs "%SOFT_MONITOR_ROOT%"') DO (
	if EXIST "%SOFT_MONITOR_ROOT%"\%%D\apps set SOFTMONITOR_VERSION=%%D
)
if NOT ["%SOFTMONITOR_VERSION%"] == [""] (
	set SOFT_MONITOR_DIR=%SOFT_MONITOR_ROOT%\%SOFTMONITOR_VERSION%
)

:: find SOFTMda version
for /f %%D in ('cscript /nologo "%SCRIPT_HOME%"\vbs\dir.vbs "%SOFT_MDA_ROOT%"') DO (
	if EXIST "%SOFT_MDA_ROOT%"\%%D\app set SOFTMDA_VERSION=%%D
)
if NOT ["%SOFTMDA_VERSION%"] == [""] (
	set SOFT_MDA_DIR=%SOFT_MDA_ROOT%\%SOFTMDA_VERSION%
)

:: find SOFTBW6Deployer version
for /f %%D in ('cscript /nologo "%SCRIPT_HOME%"\vbs\dir.vbs "%SOFT_BW6_DEPLOYER_ROOT%"') DO (
	if EXIST "%SOFT_BW6_DEPLOYER_ROOT%"\%%D\bin set SOFT_BW6_DEPLOYER_VERSION=%%D
)
if NOT ["%SOFT_BW6_DEPLOYER_VERSION%"] == [""] (
	set SOFT_BW6_DEPLOYER_DIR=%SOFT_BW6_DEPLOYER_ROOT%\%SOFT_BW6_DEPLOYER_VERSION%
)

echo #------------- > "%installFile%"
echo # %Date% %Time% >> "%installFile%"
echo #------------- >> "%installFile%"

:: Common
call :writeToInstallFile USER_HOME "!REALHOMEPATH!" "%installFile%"
call :writeToInstallFile TIBCO_ROOT "%TIBCO_ROOT%" "%installFile%"
call :writeToInstallFile TIBCO_CONFIG_DIR "%TIBCO_CONFIG_DIR%" "%installFile%"
call :writeToInstallFile TIBCO_EMS_CONFIG_DIR "%TIBCO_EMS_CONFIG_DIR%" "%installFile%"
call :writeToInstallFile TIBCO_EMS_CONFIG_FILE "%TIBCO_EMS_CONFIG_FILE%" "%installFile%"
call :writeToInstallFile TIBCO_TEA_DIR "!TIBCO_TEA_DIR!" "%installFile%"
call :writeToInstallFile TIBCO_TEA_EMS_AGENT_DIR "!TIBCO_TEA_EMS_AGENT_DIR!" "%installFile%"
call :writeToInstallFile TIBCO_HAWK_TEA_AGENT_DIR "!TIBCO_HAWK_TEA_AGENT_DIR!" "%installFile%"
call :writeToInstallFile TIBCO_EMS_DIR "!TIBCO_EMS_DIR!" "%installFile%"
call :writeToInstallFile TIBCO_BW_DIR "%BW_DIR%" "%installFile%"
call :writeToInstallFile JAVA_HOME "%TIBCO_JAVA_HOME%" "%installFile%"
call :writeToInstallFile JVM_LIB_DIR "%TIBCO_JVM_LIB_DIR%" "%installFile%"
call :writeToInstallFile JVM_LIB_SERVER "%TIBCO_JVM_LIB_SERVER%" "%installFile%"
call :writeToInstallFile JVM_LIB_SERVER_DIR "%TIBCO_JVM_LIB_SERVER_DIR%" "%installFile%"
call :writeToInstallFile SOFT_MONITOR_ROOT "%SOFT_MONITOR_ROOT%" "%installFile%"
call :writeToInstallFile SOFT_MONITOR_DIR "!SOFT_MONITOR_DIR!" "%installFile%"
call :writeToInstallFile SOFT_MDA_DIR "!SOFT_MDA_DIR!" "%installFile%"
call :writeToInstallFile SOFT_BW6_DEPLOYER_DIR "!SOFT_BW6_DEPLOYER_DIR!" "%installFile%"
call :writeToInstallFile TIBCO_HAWK_DIR "!TIBCO_HAWK_DIR!" "%installFile%"
call :writeToInstallFile TIBCO_HAWK_CONFIG_DIR "!TIBCO_HAWK_CONFIG_DIR!" "%installFile%"
call :writeToInstallFile TIBCO_RV_DIR "!TIBCO_RV_DIR!" "%installFile%"
call :writeToInstallFile AS_HOME "!TIBCO_AS_DIR!" "%installFile%"

::backward compat
call :writeToInstallFile TIBCO_TPCL_JDBC_DIR "!TIBCO_BW_SYSTEM_LIB_DIR!" "%installFile%"


echo Copy installation file to %SystemRoot% for services
copy /Y "%installFile%" "%SystemRoot%"

echo Installation file creation is OK
ECHO ------------------------------------------------------

ENDLOCAL
goto :EOF


:: -------------- end ----------------------------
:end
cd /d "%SCRIPT_HOME%"
ECHO.
ECHO ------------------------------------------------------
ECHO End install  at : %Date% %Time%
ECHO ------------------------------------------------------
ECHO.
goto :EOF

:: -------------- installArchive ----------------------------
:installArchive
setlocal
set extractedArchive=%1%
set extractedArchiveDir=%2%
set extractedArchiveDirName=%3%

echo.
echo Processing : %extractedArchiveDirName%

::archive name
set archiveName=%extractedArchiveDirName:"=%

set version=
set nocheck=
set manual=
FOR /F "eol=; tokens=2,3* delims==" %%i IN ('findstr /I "^%archiveName%" "%INSTALL_MAPPING%"') DO (
	set version=%%i
	set nocheck=%%j
	set manual=%%k
)

if "%version%" == "" (
	echo Version not found for %extractedArchiveDirName% on "%INSTALL_MAPPING%", skipping archive...	
	cd /d "%SCRIPT_HOME%"
	call :resetErrorLevel
	GOTO :EOF
)

IF EXIST "%TIBCO_ROOT%"\_installInfo\%version% (
	if NOT "%FORCE%" == "true" (
		echo %TIBCO_ROOT%\%version% already installed
		cd /d "%SCRIPT_HOME%"
		GOTO :EOF
	)
)

::  Clean
call :Cleanup %extractedArchiveDir%

::  Extract using unzip
echo Extracting %extractedArchive% in %extractedArchiveDir%
mkdir %extractedArchiveDir%
cd /d %extractedArchiveDir%
unzip -q  %extractedArchive%
IF NOT %ERRORLEVEL% == 0 (
	echo Unzip error occurred for %extractedArchive%
	call :Cleanup %extractedArchiveDir%
	exit /B %ERRORLEVEL%
)
echo Archive %extractedArchive% extracted

call :readInstallInfos
IF NOT %ERRORLEVEL% == 0 (	
	call :Cleanup %extractedArchiveDir%
	exit /B %ERRORLEVEL%
)


::find java_home
call :locateBWJava

::find ems
call :locateEMSDir

::  Replace silent file
set responseFile=
for %%F in (%extractedArchiveDir%\*.silent) do (
	cscript /nologo "%SCRIPT_HOME%"\vbs\replaceResponseFileBW6.vbs "%%F" "%TIBCO_ROOT%" "%TIBCO_CONFIG_DIR%" "%TIBCO_EMS_CONFIG_FILE%" "%TIBCO_EMS_DIR%" "%TIBCO_JAVA_HOME%" "%LGPLAssemblyPath%" "%ThirdPartiesPath%" %TIBCO_CREATE_NEW_ENV% "%TIBCO_ENVNAME%" %extractedArchiveDir%\replaced.input
	IF NOT %ERRORLEVEL% == 0 (
  	 	echo replaceResponseFile error occurred for %extractedArchive%
   		call :Cleanup %extractedArchiveDir%
   		exit /B %ERRORLEVEL%
	)
	move %extractedArchiveDir%\replaced.input "%%F"
	set responseFile=%%F
)

::  Create tmpDir
call :CreateTmpDir

::RAZ TMP
set TMP=

if not exist %TIBINSTALLER% (
	if exist ..\%TIBINSTALLER% (
		copy ..\%TIBINSTALLER% .
	) else (
		if exist ..\hotfixes\%TIBINSTALLER% (
			copy ..\hotfixes\%TIBINSTALLER% .
		) else (
			if exist "%TIBCO_ROOT%\tools\universal_installer\%TIBINSTALLER%" (
				copy "%TIBCO_ROOT%\tools\universal_installer\%TIBINSTALLER%" .
			)
		)
	)
	if not exist %TIBINSTALLER% (
		echo TIBCOUniversalInstaller not found at expected location
		call :Cleanup %extractedArchiveDir%
		exit /B 2
	)
)

::used
set USED_INSTALLER=%TIBINSTALLER%

::  launch installer
if "%manual%" == "true" (
	echo Lauching TIBCOUniversalInstaller in manual mode
	%USED_INSTALLER%
) else (
	echo Lauching TIBCOUniversalInstaller with response file %responseFile%
	%USED_INSTALLER% -silent -is:tempdir "%TMP_DIR%" -V responseFile="%responseFile%"
)

if "%nocheck%" == "true" (
	echo Not checking version for %extractedArchive%
	echo %version%>"%TIBCO_ROOT%"\_installInfo\%version%
) else (
	IF NOT EXIST "%TIBCO_ROOT%"\_installInfo\%version% (
		echo Error occurred during installation of %extractedArchive%, %TIBCO_ROOT%\_installInfo\%version% not found  after installation
		echo.
		PAUSE
		call :Cleanup %extractedArchiveDir%
		exit /B 1
	)
)

echo %extractedArchive% correctly installed
echo.
PAUSE
call :Cleanup %extractedArchiveDir%
endlocal
goto :EOF



:: --------------installSOFTMonitor ----------------------------
:installSOFTMonitor
set SOFTMONITOR_VERSION=%1%
set SOFTMONITOR_ARCHIVE=%2%
ECHO.

::archive name
set archiveName=%SOFTMONITOR_VERSION:"=%

set SOFTMONITOR_INSTALLED_VERSION=
FOR /F "eol=; tokens=2,2 delims==" %%i IN ('findstr /I "^%archiveName%" "%INSTALL_MAPPING%"') DO set SOFTMONITOR_INSTALLED_VERSION=%%i
if "%SOFTMONITOR_INSTALLED_VERSION%" == "" (
	echo Version not found for %SOFTMONITOR_VERSION% on "%INSTALL_MAPPING%", skipping archive..
	call :resetErrorLevel
	goto :EOF
)

ECHO Installing SOFTMonitor %SOFTMONITOR_VERSION%

if EXIST "%SOFT_MONITOR_ROOT%"\%SOFTMONITOR_INSTALLED_VERSION% (
	if NOT "%FORCE%" == "true" (
		echo "%SOFT_MONITOR_ROOT%\%SOFTMONITOR_INSTALLED_VERSION%" already installed
		goto :EOF
	)
	rmdir /S /Q "%SOFT_MONITOR_ROOT%\%SOFTMONITOR_INSTALLED_VERSION%"
)

:: create if not exists
if NOT EXIST "%SOFT_MONITOR_ROOT%" mkdir "%SOFT_MONITOR_ROOT%%"

:: extracting 
echo Extracting %SOFTMONITOR_ARCHIVE% into "%SOFT_MONITOR_ROOT%"
unzip -q -o -d "%SOFT_MONITOR_ROOT%" %SOFTMONITOR_ARCHIVE%
IF NOT %ERRORLEVEL% == 0 (
	echo Error occurred during extraction of %SOFTMONITOR_ARCHIVE%
	exit /B %ERRORLEVEL%
)

goto :EOF

:: --------------installPlugins ----------------------------
:installPlugins
setlocal
set SOFTAPP_VERSION=%1%
set SOFTAPP_ARCHIVE=%2%
ECHO.

::archive name
set archiveName=%SOFTAPP_VERSION:"=%

set SOFTAPP_INSTALLED_VERSION=
FOR /F "eol=; tokens=2,2 delims==" %%i IN ('findstr /I "^%archiveName%" "%INSTALL_MAPPING%"') DO set SOFTAPP_INSTALLED_VERSION=%%i
if "%SOFTAPP_INSTALLED_VERSION%" == "" (
	echo Version not found for %SOFTAPP_VERSION% on "%INSTALL_MAPPING%", skipping archive...
	call :resetErrorLevel
	goto :EOF
)

ECHO Installing %archiveName% %SOFTAPP_VERSION%


if EXIST "%TIBCO_ROOT%"\%SOFTAPP_INSTALLED_VERSION% (
	if NOT "%FORCE%" == "true" (
		echo %SOFTAPP_VERSION% already installed at %TIBCO_ROOT%\%SOFTAPP_INSTALLED_VERSION%
		goto :EOF
	)
)

::echo
echo %SOFTAPP_INSTALLED_VERSION% not found

::  Create tmpDir
call :CreateTmpDir
mkdir "%TMP_DIR%\%archiveName%"
set TMP=

:: extracting 
echo Extracting %SOFTAPP_ARCHIVE% into "%TMP_DIR%\%archiveName%"
unzip -q -o -d "%TMP_DIR%\%archiveName%" %SOFTAPP_ARCHIVE%
IF NOT %ERRORLEVEL% == 0 (
	echo Error occurred during extraction of %SOFTAPP_ARCHIVE%
	call :CleanupTmpDir
	exit /B %ERRORLEVEL%
)

::
call :locateBWJava

:: call installer
call "%TMP_DIR%\%archiveName%"\install\install.cmd "%TIBCO_ROOT%" "%BW_DIR%" "%TIBCO_JAVA_HOME%"
IF NOT %ERRORLEVEL% == 0 (
	echo Error occurred during installation of %SOFTAPP_ARCHIVE%
	call :CleanupTmpDir
	exit /B %ERRORLEVEL%
)

echo %SOFTAPP_ARCHIVE% installed
call :CleanupTmpDir
endlocal
goto :EOF


:: --------------installBundle ----------------------------
:installBundle
setlocal
set SOFTAPP_VERSION=%1%
set SOFTAPP_ARCHIVE=%2%
ECHO.

::archive name
set archiveName=%SOFTAPP_VERSION:"=%

:: Find last bw versions & java
call :locateBWJava
if ["!BW_VERSION!"] == [""] goto :EOF

:: resolve
set TIBCO_BW_SYSTEM_SHARED_DIR=%TIBCO_ROOT%\bw\%BW_VERSION%\system\shared

::check install
IF NOT EXIST "%TIBCO_BW_SYSTEM_SHARED_DIR%" (
	echo "%TIBCO_BW_SYSTEM_SHARED_DIR%" not found
	goto :EOF
)

ECHO Installing Bundle %archiveName% to %TIBCO_BW_SYSTEM_SHARED_DIR%
call :copyVersion "%archiveName%" "%SOFTAPP_ARCHIVE%" "%TIBCO_BW_SYSTEM_SHARED_DIR%"
IF NOT %ERRORLEVEL% == 0 (
	echo Error occurred during installation of %SOFTAPP_ARCHIVE%
	exit /B %ERRORLEVEL%
)

endlocal
goto :EOF



:: --------------installSOFTApps ----------------------------
:installSOFTApps
set SOFTAPP_VERSION=%1%
set SOFTAPP_ARCHIVE=%2%
set ARTEFACT=%3
set TARGET_DIR=%4
set INSTALL_SCRIPT=%5
ECHO.

::archive name
set archiveName=%SOFTAPP_VERSION:"=%

::remove "
set TARGET_DIR=%TARGET_DIR:"=%

set SOFTAPP_INSTALLED_VERSION=
FOR /F "eol=; tokens=2,2 delims==" %%i IN ('findstr /I "^%archiveName%" "%INSTALL_MAPPING%"') DO set SOFTAPP_INSTALLED_VERSION=%%i
if "%SOFTAPP_INSTALLED_VERSION%" == "" (
	echo Version not found for %SOFTAPP_VERSION% on "%INSTALL_MAPPING%", skipping archive..
	call :resetErrorLevel
	goto :EOF
)

ECHO Installing %ARTEFACT% %SOFTAPP_VERSION%

if EXIST "%TARGET_DIR%"\%SOFTAPP_INSTALLED_VERSION% (
	if NOT "%FORCE%" == "true" (
		echo "%TARGET_DIR%\%SOFTAPP_INSTALLED_VERSION%" already installed
		goto :EOF
	)
)

::  Create tmpDir
call :CreateTmpDir

:: extracting 
echo Extracting %SOFTAPP_ARCHIVE% into "%TMP_DIR%"
unzip -q -o -d "%TMP_DIR%" %SOFTAPP_ARCHIVE%
IF NOT %ERRORLEVEL% == 0 (
	echo Error occurred during extraction of %SOFTAPP_ARCHIVE%
	call :CleanupTmpDir
	exit /B %ERRORLEVEL%
)

:: call installer
call "%TMP_DIR%"\%SOFTAPP_INSTALLED_VERSION%\%INSTALL_SCRIPT% "%TIBCO_ROOT%" true
IF NOT %ERRORLEVEL% == 0 (
	echo Error occurred during installation of %SOFTAPP_ARCHIVE%
	call :CleanupTmpDir
	exit /B %ERRORLEVEL%
)

echo %ARTEFACT% installed at %TARGET_DIR%\%SOFTAPP_INSTALLED_VERSION%
call :CleanupTmpDir
goto :EOF


:: -------------- disableWindowsService ----------------------------
:disableWindowsService

cscript /nologo "%SCRIPT_HOME%"\vbs\disableServices.vbs
IF NOT %ERRORLEVEL% == 0 (
	call :resetErrorLevel
)
goto :EOF

:: -------------- locateBWJava ----------------------------
:locateBWJava
set BW_VERSION=
set TIBCO_JVM_LIB_DIR=
set TIBCO_JVM_LIB_SERVER_DIR=
set TIBCO_JVM_LIB_SERVER=
set TIBCO_JAVA_HOME=

for /f %%D in ('cscript /nologo "%SCRIPT_HOME%"\vbs\dir.vbs "%TIBCO_ROOT%"\bw') DO (
	if EXIST "%TIBCO_ROOT%"\bw\%%D\bin\bwcommon.tra set BW_VERSION=%%D
)

if ["%BW_VERSION%"] == [""] (
	echo BW_VERSION not found
	goto :EOF
)

set BW_DIR=%TIBCO_ROOT%\bw\%BW_VERSION%

FOR /F "eol=; tokens=2,2 delims==" %%i IN ('findstr /I /C:tibco.env.TIBCO_JVM_LIB_DIR "%BW_DIR%"\bin\bwcommon.tra') DO set TIBCO_JVM_LIB_DIR=%%i
FOR /F "eol=; tokens=2,2 delims==" %%i IN ('findstr /I /C:tibco.env.TIBCO_JVM_LIB_SERVER_DIR "%BW_DIR%"\bin\bwcommon.tra') DO set TIBCO_JVM_LIB_SERVER_DIR=%%i
FOR /F "eol=; tokens=2,2 delims==" %%i IN ('findstr /I /C:tibco.env.TIBCO_JVM_LIB_SERVER "%BW_DIR%"\bin\bwcommon.tra') DO set TIBCO_JVM_LIB_SERVER=%%i
FOR /F "eol=; tokens=2,2 delims==" %%i IN ('findstr /I /C:tibco.env.TIBCO_JAVA_HOME "%BW_DIR%"\bin\bwcommon.tra') DO set TIBCO_JAVA_HOME=%%i
goto :EOF

:: --------------  locateEMSDir ----------------------------
:locateEMSDir
set EMS_VERSION=
set TIBCO_EMS_DIR=

for /f %%D in ('cscript /nologo "%SCRIPT_HOME%"\vbs\dir.vbs "%TIBCO_ROOT%"\ems') DO (
	if EXIST "%TIBCO_ROOT%"\ems\%%D\bin\tibemsd.exe set EMS_VERSION=%%D
)
if NOT ["%EMS_VERSION%"] == [""] (
	set TIBCO_EMS_DIR=%TIBCO_ROOT%\ems\%EMS_VERSION%
)
goto :EOF

:: --------------readInstallInfos ----------------------------
:readInstallInfos
call :readInstallInfosKey name
if NOT ["%name%"] == [""] (
	echo found existing evironement %name% at %TIBCO_ROOT% on %TIBCO_ENV_INFOS%
	set TIBCO_ENVNAME=%name%
	set TIBCO_CREATE_NEW_ENV=false			
)

call :readInstallInfosKey configDir
if NOT ["%configDir%"] == [""] (
	echo found existing config dir %configDir% at %TIBCO_ROOT% on %TIBCO_ENV_INFOS%
	set TIBCO_CONFIG_DIR=%configDir%
	set TIBCO_EMS_CONFIG_DIR=%configDir%\cfgmgmt\ems\data
	set TIBCO_EMS_CONFIG_FILE=!TIBCO_EMS_CONFIG_DIR!\tibemsd.conf
)
	
goto :EOF


:: --------------readInstallInfosKey ----------------------------
:readInstallInfosKey
set key=%1%
for /f "delims=" %%a in ('cscript /nologo  "%SCRIPT_HOME%"\vbs\readInstallInfos.vbs "%TIBCO_ENV_INFOS%" "%TIBCO_ROOT%" %key%') do (	
	set %key%=%%a
)
goto :EOF

:: --------------copyVersionExcluding ----------------------------
:copyVersionExcluding
set fileVer=%1
set fileToCopy=%2
set dest=%3
set excluding=%4

::remove
set fileVer=%fileVer:"=%
set fileToCopy=%fileToCopy:"=%
set dest=%dest:"=%

set isExcluded=
for /F "delims=" %%i in ('echo %fileVer%^|FINDSTR %excluding%') do set isExcluded=%%i
call :resetErrorLevel
if "%isExcluded%" == "" call :copyVersion "%fileVer%" "%fileToCopy%" "%dest%"
goto :EOF

:: --------------copyVersion ----------------------------
:copyVersion
SETLOCAL
set fileVer=%1
set fileToCopy=%2
set dest=%3

::remove
set fileVer=%fileVer:"=%
set fileToCopy=%fileToCopy:"=%
set dest=%dest:"=%

set fileVerFullName=
FOR %%A IN ("%fileToCopy%") DO set fileVerFullName=%%~nxA

::get file name without version
set fileNotVer=
for /f "delims=" %%a in ('cscript /nologo  "%SCRIPT_HOME%"\vbs\substringBeforeLast.vbs %fileVer% -') do (
	set fileNotVer=%%a
)

if not exist "%dest%\%fileVerFullName%" (
	IF NOT ["%fileNotVer%"] == [""] (	
		for %%F in ("%dest%\%fileNotVer%-*.*") do (
			echo Removing [%%F]
			del /F "%%F"			
		) 	
		echo copying [%fileVer%]
		copy /Y "%fileToCopy%" "%dest%"
	)
) else (
	echo %fileVer% already exists	
	IF NOT ["%fileNotVer%"] == [""] (	
		for %%F in ("%dest%\%fileNotVer%-*.*") do (
			if NOT "%%~nF" == "%fileVer%" (
				echo Removing [%%F]
				del /F "%%F"			
			)
		) 			
	)
)
ENDLOCAL
goto :EOF

:: --------------removeVersion ----------------------------
:removeVersion
set fileVer=%1
set dest=%2

::remove
set fileVer=%fileVer:"=%
set dest=%dest:"=%

::get file name without version
set fileNotVer=
for /f "delims=" %%a in ('cscript /nologo  "%SCRIPT_HOME%"\vbs\substringBeforeLast.vbs %fileVer% -') do (
	set fileNotVer=%%a
)

IF NOT ["%fileNotVer%"] == [""] (	
	for %%F in ("%dest%\%fileNotVer%*.*") do (		
		echo removing %%F
		del /F %%F
	)
)

goto :EOF

:: --------------CreateTmpDir ----------------------------
:CreateTmpDir
IF EXIST "%TMP_DIR%"/ (
	rmdir /S /Q "%TMP_DIR%"	
)
mkdir "%TMP_DIR%"
set TMP="%TMP_DIR%"
echo Create temp dir Ok
goto :EOF

:: --------------Cleanup ----------------------------
:Cleanup
cd /d "%SCRIPT_HOME%"
IF EXIST "%TMP_DIR%" (	
	rmdir /S /Q "%TMP_DIR%"
)
IF EXIST %1% (	
	rmdir /S /Q %1%
)
call :resetErrorLevel
echo cleanup Ok
goto :EOF

:: -------------- CleanupTmpDir ----------------------------
:CleanupTmpDir
IF EXIST %TMP_DIR% (	
	rmdir /S /Q %TMP_DIR%
)
call :resetErrorLevel
echo cleanup Ok
goto :EOF

:: -------------- writeToInstallFile ----------------------------
:writeToInstallFile
set key=%1%
set value=%2%
set outfile=%3%

set valueJava=%value:\=/%
IF EXIST %value% (
	echo %key%=%valueJava:"=%>>%outfile%
)
goto :EOF

:: -------------- resetErrorLevel ----------------------------
:resetErrorLevel
echo.a|FIND "a">nul
goto :EOF

:: --------  For previous installer versions ----------------
:cleanupPreviousInstaller
IF NOT EXIST "%TIBCO_ENV_INFOS%" (
	IF EXIST "%CommonProgramFiles%\InstallShield\Universal" (
		ATTRIB -R -A -S -H /S /D "%CommonProgramFiles%\InstallShield"
		rmdir /S /Q "%CommonProgramFiles%\InstallShield\Universal"
	)
	
::X64 Compat
	IF EXIST "%CommonProgramFiles(x86)%\InstallShield\Universal" (
		ATTRIB -R -A -S -H /S /D "%CommonProgramFiles(x86)%\InstallShield"
		rmdir /S /Q "%CommonProgramFiles(x86)%\InstallShield\Universal"
	)
)

IF EXIST "%installFile%" (
	move "%installFile%" "%installFile%.old"
	call :resetErrorLevel
)
IF EXIST "%SystemRoot%\%installFileName%" (
	move  "%SystemRoot%\%installFileName%" "%SystemRoot%\%installFileName%.old"
	call :resetErrorLevel
)
goto :EOF

:: --------  restore ----------------
IF EXIST "%installFile%.old" (
	IF NOT EXIST "%installFile%" (
		echo restoring install file %installFile%
		move "%installFile%.old" "%installFile%"
	)	
)
IF EXIST "%SystemRoot%\%installFileName%.old" (
	IF NOT EXIST "%SystemRoot%\%installFileName%" (
		echo restoring install file %SystemRoot%\%installFileName%
		move "%SystemRoot%\%installFileName%.old" "%SystemRoot%\%installFileName%"
	)	
)
