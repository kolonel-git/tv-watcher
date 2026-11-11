# Builds the Windows release and packs it into a portable zip.
#
#   powershell -ExecutionPolicy Bypass -File tools\package_windows.ps1
#
# Output: dist\tv-watcher-<version>-windows.zip
# The zip never contains .env (the TMDB token stays on this computer).
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

$pubspec = Get-Content pubspec.yaml -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\S+?)(\+\S+)?\s*$') { throw 'version not found in pubspec.yaml' }
$version = $Matches[1]

flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }

$release = 'build\windows\x64\runner\Release'
if (-not (Test-Path "$release\tv_watcher.exe")) { throw "tv_watcher.exe not found in $release" }

$name = "tv-watcher-$version-windows"
$stage = "dist\$name"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item "$release\*" $stage -Recurse

# Safety net: make sure no secrets or databases ride along.
Get-ChildItem $stage -Recurse -Include '.env', '*.sqlite', '*.db' | Remove-Item -Force

Copy-Item 'tools\INSTALL.txt' "$stage\INSTALL.txt"

$zip = "dist\$name.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$stage\*" -DestinationPath $zip
$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host "Done: $zip ($mb MB)"
