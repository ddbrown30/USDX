@echo off

REM Compiles UltraStar Deluxe and packages it into a portable zip, in
REM one step: runs build.bat, then make_portable.ps1. Run this from
REM the root of your USDX checkout. See build.bat for compiler setup
REM notes (lazbuild location, i386 cross-compiler requirement).
REM
REM Any arguments this script is given are forwarded to
REM make_portable.ps1, e.g.:
REM   build_and_make_portable.bat -IncludeSongs -OutputZip usdx-full.zip

setlocal

set "REPO_ROOT=%~dp0"

REM Tells build.bat this is a chained call, so it skips its own
REM "press any key" pause - we want one continuous run, not a stop
REM halfway through.
set "USDX_BUILD_CHAINED=1"
call "%REPO_ROOT%build.bat"
set "USDX_BUILD_CHAINED="

if errorlevel 1 exit /b 1

echo.
echo Creating portable package...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%make_portable.ps1" %*

pause
