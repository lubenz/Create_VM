set LOCALAPPDATA=%USERPROFILE%\AppData\Local
set PSExecutionPolicyPreference=Unrestricted
TZUTIL /s "Greenwich Standard Time"
powershell "%systemdrive%\scripts\setup.ps1" -Argument >"%systemdrive%\scripts\myscript_log.txt" 2>&1