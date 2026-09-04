@echo off
setlocal EnableExtensions
title Driver Store Cleanup - Windows 11 25H2

rem Removes driver packages that no device references, using the same
rem pnpclean entry point that Disk Cleanup's "Device driver packages" uses.
rem Takes a before/after snapshot so you can see exactly what changed.
rem Does NOT touch Windows Update policy. Does NOT force a restart.
rem Right-click -> Run as administrator.

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Please right-click this file and choose "Run as administrator".
    pause
    exit /b 1
)

set "LOGDIR=%USERPROFILE%\Desktop\repair-logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
set "LOG=%LOGDIR%\driver-cleanup.txt"
set "REPO=%SystemRoot%\System32\DriverStore\FileRepository"
echo ===== Driver Store cleanup started %date% %time% ===== >> "%LOG%"

echo [1/4] Snapshot BEFORE...
pnputil /enum-drivers > "%LOGDIR%\DriverStore_before.txt" 2>&1
powershell -NoProfile -Command "'{0:N2} GB before' -f ((Get-ChildItem -Recurse -Force '%REPO%' -EA SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB)" >> "%LOG%"

echo [2/4] Removing unreferenced driver packages...
if not exist "%SystemRoot%\System32\pnpclean.dll" (
    echo pnpclean.dll not found. Nothing removed. >> "%LOG%"
    echo pnpclean.dll not found. Nothing removed.
    pause
    exit /b 2
)
"%SystemRoot%\System32\rundll32.exe" "%SystemRoot%\System32\pnpclean.dll",RunDLL_PnpClean /DRIVERS /MAXCLEAN

echo [3/4] Snapshot AFTER...
pnputil /enum-drivers > "%LOGDIR%\DriverStore_after.txt" 2>&1
powershell -NoProfile -Command "'{0:N2} GB after' -f ((Get-ChildItem -Recurse -Force '%REPO%' -EA SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB)" >> "%LOG%"

echo [4/4] Done.
echo.
type "%LOG%"
echo.
echo Compare these two files to see what was removed:
echo   %LOGDIR%\DriverStore_before.txt
echo   %LOGDIR%\DriverStore_after.txt
echo No restart was forced. Restart when convenient.
pause
endlocal
