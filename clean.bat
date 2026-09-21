@echo off

REM Deletes the FPC build cache (build\fpc-x86_64-win64 and
REM build\fpc-i386-win32) so the next build.bat / build_and_make_portable.bat
REM run recompiles everything from scratch. Run this from the root of your
REM USDX checkout.
REM
REM Why this is needed: lazbuild normally runs src\clean.bat as a pre-build
REM step to do this automatically, passing it a *relative* path. But on a
REM checkout living on a UNC path (like \\pox-box\...), cmd can't set that
REM as a process's working directory and silently falls back to
REM C:\Windows instead - so src\clean.bat's deletes silently target the
REM wrong location and never actually clean anything (see build.bat's
REM comment above its own workaround for the same issue). Stale compiled
REM units (.ppu/.o) then pile up build after build, which can eventually
REM cause bogus "Incompatible types" errors or internal compiler crashes
REM that have nothing to do with your actual source changes.
REM
REM If a build starts failing with errors that don't make sense given
REM what you actually changed, run this script first, then build again.

setlocal

set "REPO_ROOT=%~dp0"

for %%D in (fpc-x86_64-win64 fpc-i386-win32) do (
    if exist "%REPO_ROOT%build\%%D" (
        echo Removing build\%%D ...
        rd /s /q "%REPO_ROOT%build\%%D"
    )
)

echo.
echo Build cache cleared.

if not defined USDX_BUILD_CHAINED pause
