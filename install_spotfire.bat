@echo off
setlocal

rem ---------------------------------------------------------------------------
rem
rem This script will install Spotfire server on Window 2016.
rem
rem 		* Before using this script you need to setting up the Oracle database:
rem         * Open a command prompt as an administrator
rem         * Edit the default parameters in the following script. 
rem         * Make sure that none of the ports that you select are already in use.

rem ---------------------------------------------------------------------------

rem ** Set these variable to reflect the local environment:

rem The installation directory.

set EXEC =<PATTH>\setup-win64.exe

set INSTALLDIR=C:\<MySpotfireServer>

rem ** The available options are Create and DoNotCreate

set SPOTFIRE_WINDOWS_SERVICE=Create

rem Used for communication with Spotfire clients. The default is 80 ... Port Example 10082

set SERVER_FRONTEND_PORT=<SET_PORT>

rem Used for key exchange to set up trusted communication 
rem between the Spotfire Server and nodes. The default is 9080.

set SERVER_BACKEND_REGISTRATION_PORT=<SET_PORT>

rem Used for encrypted traffic between nodes. Thedefault is 9443.

set SERVER_BACKEND_COMMUNICATION_PORT=<SET_PORT>

set NODEMANAGER_HOST_NAMES=localhost

set LOG_FILE=<SET_INSTALL_LOG_FILE>

rem end of the variables



rem Create the tablespaces and user
@echo Creating Spotfire Server table spaces and user
EXEC "%INSTALLDIR%" "%ROOTFOLDER%" "%SPOTFIRE_WINDOWS_SERVICE%" "%SERVER_FRONTEND_PORT%" "%SERVER_BACKEND_REGISTRATION_PORT%" "%SERVER_BACKEND_COMMUNICATION_PORT%" "%NODEMANAGER_HOST_NAMES%" -silenct -log "%LOG_FILE%"
if %errorlevel% neq 0 (
  @echo Error while running spotfire installation script 'install_spotfire.bat'
  @echo For more information consult the log file %LOG_FILE%
  exit /B 1
)


goto end


:end

@echo -----------------------------------------------------------------
@echo Install of TIBCO Spotfire Server successful
@echo Please review the log file [%LOG_FILE%] for any errors or warnings!
endlocal
