@echo off
REM Double-click wrapper for update_install.ps1.
REM
REM This must be run as Administrator (it writes into Program Files) -
REM right-click this file and choose "Run as administrator". It will
REM tell you plainly and stop if you forget, rather than failing
REM partway through the copy.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update_install.ps1" %*
pause
