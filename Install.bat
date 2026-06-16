@echo off
REM MediaScribe installer launcher.
REM Friendly install command from PowerShell:
REM powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1

cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"

echo.
echo MediaScribe setup has finished.
echo You can close this window, or press any key to close it.
pause >nul