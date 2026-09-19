@echo off
REM Double-click wrapper for make_portable.ps1 - run this from the
REM root of your USDX checkout (same folder as dldlls.py and game\).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make_portable.ps1" %*
pause
