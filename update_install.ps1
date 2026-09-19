<#
.SYNOPSIS
  Updates an existing installed copy of UltraStar Deluxe from a
  portable zip (as produced by make_portable.ps1).

.DESCRIPTION
  Extracts the zip and copies its contents into the installed USDX
  folder, overwriting the exe/DLLs/themes/etc. with the new build.
  This is additive, not wipe-and-replace: anything already in the
  install folder that ISN'T in the zip - your config.ini, Songs,
  Playlists, Screenshots - is left completely alone, since the
  portable zip deliberately excludes exactly those (see
  make_portable.ps1's exclusion list) and this script only ever
  copies FROM the zip's contents.

  Must be run as Administrator, since it writes into Program Files.
  This deliberately does NOT try to self-elevate: self-elevating a
  script whose working directory is a network path (\\server\share)
  is a known source of silent failures on Windows. Simpler and more
  reliable to just re-run it elevated yourself when asked.

.PARAMETER ZipPath
  Path to the portable zip. Defaults to UltraStarDeluxe-portable.zip
  next to this script (i.e. wherever make_portable.ps1 wrote it).

.PARAMETER InstallDir
  Path to the existing installed copy of USDX.
  Defaults to "C:\Program Files (x86)\UltraStar Deluxe".

.PARAMETER Force
  Skip confirmation prompts and close UltraStar Deluxe automatically
  if it's running.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File update_install.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File update_install.ps1 -ZipPath D:\builds\usdx.zip -Force
#>

param(
    [string]$ZipPath = (Join-Path $PSScriptRoot "UltraStarDeluxe-portable.zip"),
    [string]$InstallDir = "C:\Program Files (x86)\UltraStar Deluxe",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# --- 0. Must be elevated --------------------------------------------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This needs to write into '$InstallDir', which requires Administrator rights. Right-click update_install.bat and choose 'Run as administrator', then try again."
}

# --- 1. Sanity checks ------------------------------------------------------
if (-not (Test-Path $ZipPath)) {
    Write-Error "Zip not found: $ZipPath`nRun make_portable.ps1 first, or pass -ZipPath to point at your zip."
}
if (-not (Test-Path $InstallDir)) {
    Write-Error "Install dir not found: $InstallDir`nThis script updates an EXISTING install - run the real installer first if USDX isn't installed there yet."
}
if (-not (Test-Path (Join-Path $InstallDir "ultrastardx.exe"))) {
    Write-Error "'$InstallDir' doesn't look like a USDX install (no ultrastardx.exe there) - double check -InstallDir."
}

Write-Host "Zip:     $ZipPath"
Write-Host "Install: $InstallDir"

# --- 2. Close USDX if it's running -----------------------------------------
$proc = Get-Process -Name "ultrastardx" -ErrorAction SilentlyContinue
if ($proc) {
    if (-not $Force) {
        $answer = Read-Host "UltraStar Deluxe is currently running. Close it and continue? (y/N)"
        if ($answer -notmatch "^[Yy]") {
            Write-Host "Aborted."
            exit 1
        }
    }
    Write-Host "Closing UltraStar Deluxe..."
    $proc | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# --- 3. Confirm --------------------------------------------------------------
if (-not $Force) {
    Write-Host ""
    Write-Host "This will overwrite the exe/DLLs/themes/etc. in '$InstallDir' with the contents of the zip."
    Write-Host "Your config.ini, Songs, Playlists, and Screenshots there are not touched - the zip never contains them."
    $answer = Read-Host "Continue? (y/N)"
    if ($answer -notmatch "^[Yy]") {
        Write-Host "Aborted."
        exit 1
    }
}

# --- 4. Extract the zip to a temp folder, then copy over the install -------
$extractTemp = Join-Path $env:TEMP ("usdx_update_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $extractTemp | Out-Null

try {
    Write-Host "Extracting zip..."
    Expand-Archive -Path $ZipPath -DestinationPath $extractTemp -Force

    Write-Host "Copying into $InstallDir ..."
    Copy-Item -Path (Join-Path $extractTemp "*") -Destination $InstallDir -Recurse -Force
}
finally {
    Remove-Item $extractTemp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Done. '$InstallDir' has been updated."
