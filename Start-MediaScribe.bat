@echo off
REM Friendly start command from PowerShell: .\Start-MediaScribe.bat
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0transcribe.ps1"