@echo off

REM Compiles UltraStar Deluxe via lazbuild (Lazarus's command-line
REM build tool) - no MSYS2/autotools/make needed, and this never opens
REM the Lazarus IDE. Run this from the root of your USDX checkout.
REM
REM Builds src\ultrastardx-win.lpi - the same project file "Compiling
REM using Lazarus" in COMPILING.md describes building interactively,
REM just driven from the command line instead.
REM
REM If lazbuild.exe isn't on PATH and isn't at the default Lazarus
REM install location, set LAZBUILD to its full path first, e.g.:
REM   set "LAZBUILD=C:\Lazarus\lazbuild.exe"
REM
REM Also needs Lazarus's own bundled FPC to actually be able to cross
REM compile - if it can't (error mentions ppc386.exe/ppcx64.exe or
REM "cannot find real compiler for this platform"), install the
REM standalone Free Pascal Compiler package too (it adds the missing
REM cross-compilers alongside Lazarus's own native-only one) and point
REM Lazarus's Environment Options -> Files -> "Compiler executable" at
REM its fpc.exe, e.g. C:\FPC\3.2.2\bin\i386-win32\fpc.exe.
REM
REM Forces the x86_64/win64 target explicitly rather than trusting
REM ultrastardx-win.lpi's own checked-in default (i386/win32): every
REM DLL this install actually ships (bass.dll, SDL2.dll, lua54.dll,
REM portaudio_x64.dll, etc.) is 64-bit, so a 32-bit exe fails to start
REM at all (Windows error 0xc000007b) even though it compiles cleanly.

setlocal

set "REPO_ROOT=%~dp0"
set "LPI_FILE=%REPO_ROOT%src\ultrastardx-win.lpi"

if defined LAZBUILD goto :found_lazbuild

where lazbuild.exe >nul 2>&1
if %errorlevel%==0 (
    set "LAZBUILD=lazbuild.exe"
    goto :found_lazbuild
)

if exist "C:\Lazarus\lazbuild.exe" (
    set "LAZBUILD=C:\Lazarus\lazbuild.exe"
    goto :found_lazbuild
)

echo Could not find lazbuild.exe.
echo Install Lazarus (see COMPILING.md's "Compiling using Lazarus"
echo section) or set LAZBUILD to its full path first, e.g.:
echo   set "LAZBUILD=C:\Lazarus\lazbuild.exe"
if not defined USDX_BUILD_CHAINED pause
exit /b 1

:found_lazbuild

if not exist "%LPI_FILE%" (
    echo %LPI_FILE% not found - run this script from the root of your USDX checkout.
    if not defined USDX_BUILD_CHAINED pause
    exit /b 1
)

REM The project's pre-build step (src\clean.bat) does a relative
REM "mkdir %%OBJ_PATH%%" against its own working directory. Since this
REM checkout lives on a UNC path, cmd can't set that as a process's
REM current directory and silently falls back to C:\Windows instead,
REM so that mkdir (and the cleanup deletes around it) end up targeting
REM the wrong location entirely rather than failing loudly. Harmless
REM for the deletes (nothing to clean anyway), but the compiler
REM genuinely needs this directory to exist to write its output into -
REM so create it ourselves first, with an absolute path.
if not exist "%REPO_ROOT%build\fpc-x86_64-win64" mkdir "%REPO_ROOT%build\fpc-x86_64-win64"

echo Compiling UltraStar Deluxe with "%LAZBUILD%" ...
"%LAZBUILD%" --cpu=x86_64 --os=win64 "%LPI_FILE%"

if errorlevel 1 (
    echo.
    echo Build failed - see the compiler output above.
    if not defined USDX_BUILD_CHAINED pause
    exit /b 1
)

if not exist "%REPO_ROOT%game\ultrastardx.exe" (
    echo.
    echo lazbuild reported success, but game\ultrastardx.exe is missing - something's wrong.
    if not defined USDX_BUILD_CHAINED pause
    exit /b 1
)

echo.
echo Build succeeded: game\ultrastardx.exe

if not defined USDX_BUILD_CHAINED pause
