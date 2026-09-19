<#
.SYNOPSIS
  Builds a portable, zippable copy of UltraStar Deluxe from an
  already-compiled `game` folder.

.DESCRIPTION
  1. Runs the project's own dldlls.py to fetch the runtime DLLs USDX
     needs (SDL2/SDL2_image/FFmpeg/SQLite/PortAudio/Lua, pinned to the
     exact commit this checkout expects, plus bass.dll separately) -
     the same thing CI does, not a guessed DLL list.
  2. Stages a clean copy of `game\`, excluding exactly what this
     project's own .gitignore treats as machine-specific/generated
     rather than part of the shipped app: config.ini, songs\,
     playlists\, screenshots\, *.db, *.log, *.debug.
  3. Zips the staged copy.

  Run this from the root of your USDX checkout (same folder as
  dldlls.py and the `game` directory), AFTER a successful build.

.PARAMETER OutputZip
  Name of the zip file to produce (default: UltraStarDeluxe-portable.zip).

.PARAMETER IncludeSongs
  Also bundle game\songs\ into the zip. Off by default - your song
  library is usually large and separate from "the app".

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File make_portable.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File make_portable.ps1 -IncludeSongs -OutputZip usdx-full.zip
#>

param(
    [string]$OutputZip = "UltraStarDeluxe-portable.zip",
    [switch]$IncludeSongs
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$gameDir  = Join-Path $repoRoot "game"
$exePath  = Join-Path $gameDir "ultrastardx.exe"
$dldllsPy = Join-Path $repoRoot "dldlls.py"

if (-not (Test-Path $exePath)) {
    Write-Error "game\ultrastardx.exe not found under $repoRoot - build USDX first, then run this script."
}
if (-not (Test-Path $dldllsPy)) {
    Write-Error "dldlls.py not found under $repoRoot - run this script from the root of your USDX checkout."
}

# --- 1. Fetch the DLLs USDX actually depends on -----------------------
Write-Host "Fetching required DLLs (dldlls.py)..."
Push-Location $repoRoot
try {
    py dldlls.py
    if ($LASTEXITCODE -ne 0) {
        Write-Error "dldlls.py failed (exit $LASTEXITCODE) - check the output above. Likely a network issue, GitHub API rate limit, or no matching release for this commit."
    }
} finally {
    Pop-Location
}

$dllZip = Join-Path $repoRoot "usdx-dlls-x86_64.zip"
if (-not (Test-Path $dllZip)) {
    Write-Error "dldlls.py did not produce usdx-dlls-x86_64.zip - check its output above."
}

Write-Host "Extracting DLLs into game\ ..."
$dllTemp = Join-Path $repoRoot "_dlltemp"
if (Test-Path $dllTemp) { Remove-Item $dllTemp -Recurse -Force }
Expand-Archive -Path $dllZip -DestinationPath $dllTemp -Force
Get-ChildItem -Path $dllTemp -Filter "*.dll" -Recurse | ForEach-Object {
    Copy-Item $_.FullName -Destination $gameDir -Force
}
Remove-Item $dllTemp -Recurse -Force

# Clean up dldlls.py's own temp downloads so re-running this script
# doesn't accumulate cruft in the repo root.
Remove-Item $dllZip -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $repoRoot "bass24.zip") -Force -ErrorAction SilentlyContinue

# --- 2. Stage a clean copy of game\ for packaging ----------------------
# Top-level-only exclusions, matching this repo's own .gitignore
# entries (/game/config.ini, /game/songs/, etc. - the leading slash
# there means "directly under game/", so we only need to filter at
# the top level, not recursively).
$stageDir = Join-Path $repoRoot "_portable_stage"
if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
New-Item -ItemType Directory -Path $stageDir | Out-Null

$excludeDirNames  = @("playlists", "screenshots")
if (-not $IncludeSongs) { $excludeDirNames += "songs" }
$excludeFileNames = @("config.ini")
$excludeExtensions = @(".db", ".log", ".debug")

Write-Host "Staging a clean copy of game\ ..."
Get-ChildItem -Path $gameDir -Force | ForEach-Object {
    if ($_.PSIsContainer) {
        if ($excludeDirNames -contains $_.Name) {
            Write-Host "  skipping folder: $($_.Name)"
            return
        }
        Copy-Item $_.FullName -Destination $stageDir -Recurse -Force
    }
    else {
        if ($excludeFileNames -contains $_.Name) { return }
        if ($excludeExtensions -contains $_.Extension) { return }
        Copy-Item $_.FullName -Destination $stageDir -Force
    }
}

# --- 3. Zip it -----------------------------------------------------------
$zipPath = Join-Path $repoRoot $OutputZip
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Write-Host "Creating $OutputZip ..."
Compress-Archive -Path (Join-Path $stageDir "*") -DestinationPath $zipPath

Remove-Item $stageDir -Recurse -Force

Write-Host ""
Write-Host "Done: $zipPath"
Write-Host "On the target machine: extract it anywhere and run ultrastardx.exe."
if (-not $IncludeSongs) {
    Write-Host "Note: game\songs\ was not included - pass -IncludeSongs to bundle your song library too."
}
