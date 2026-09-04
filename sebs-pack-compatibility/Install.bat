@echo off
setlocal
cd /d "%~dp0"

echo.
echo Seb's Pack + OGSR compatibility installer
echo.

if "%~2"=="" (
    if "%~1"=="" (
        powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Install-SebsPackCompatibility.ps1"
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Install-SebsPackCompatibility.ps1" -GameDir "%~1"
    )
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Install-SebsPackCompatibility.ps1" -GameDir "%~1" -SebsDir "%~2"
)

set "ERR=%ERRORLEVEL%"
echo.
if not "%ERR%"=="0" (
    echo Installer exited with code %ERR%.
)
pause
exit /b %ERR%
