@echo off
setlocal EnableExtensions
title Hide recovery partition drive letter (R:)

rem Removes the drive letter R: from the Windows RE recovery partition and
rem confirms Windows RE is still enabled. Nothing is deleted.
rem Right-click -> Run as administrator.

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Please right-click this file and choose "Run as administrator".
    pause
    exit /b 1
)

set "LOGDIR=%USERPROFILE%\Desktop\repair-logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
set "LOG=%LOGDIR%\02-hide-recovery.txt"
echo ===== %date% %time% ===== >> "%LOG%"

if exist R:\ (
    echo R: exists. Removing drive letter from the recovery partition...
    echo mountvol R: /D >> "%LOG%"
    mountvol R: /D >> "%LOG%" 2>&1
    if exist R:\ (
        echo R: is still present. Trying diskpart...
        (
        echo select volume R
        echo remove letter=R
        echo exit
        ) > "%TEMP%\hide-r.txt"
        diskpart /s "%TEMP%\hide-r.txt" >> "%LOG%" 2>&1
        del "%TEMP%\hide-r.txt" >nul 2>&1
    )
) else (
    echo R: does not exist. Nothing to do.
    echo R: not present >> "%LOG%"
)

echo.
echo Windows RE status:
reagentc /info > "%TEMP%\re-info.txt" 2>&1
type "%TEMP%\re-info.txt"
type "%TEMP%\re-info.txt" >> "%LOG%"

findstr /i /c:"Disabled" /c:"已禁用" "%TEMP%\re-info.txt" >nul
if "%errorlevel%"=="0" (
    echo.
    echo Windows RE is disabled. Re-enabling...
    reagentc /enable >> "%LOG%" 2>&1
    reagentc /info
    reagentc /info >> "%LOG%" 2>&1
)
del "%TEMP%\re-info.txt" >nul 2>&1

echo.
echo Done. Log: %LOG%
echo If R: still shows in File Explorer, restart once.
pause
endlocal
