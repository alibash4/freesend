# Zips the Flutter Windows release folder. The zip is what the updater
# downloads; it contains free_send.exe plus the DLLs and data that exe needs.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Bundle = Join-Path $Root "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $Bundle "free_send.exe"))) {
  throw "Windows build is missing. Run: flutter build windows --release"
}
$Version = $env:VERSION
if (-not $Version -and $env:CI_COMMIT_TAG) { $Version = $env:CI_COMMIT_TAG }
if (-not $Version) {
  $line = Select-String -Path (Join-Path $Root "pubspec.yaml") -Pattern "^version:\s*([^+]+)" | Select-Object -First 1
  $Version = $line.Matches[0].Groups[1].Value.Trim()
}
$Version = $Version.TrimStart("v")
$Project = if ($env:PROJECT_NAME) { $env:PROJECT_NAME } else { "freesend" }
$Dist = Join-Path $Root "dist"
New-Item -ItemType Directory -Force -Path $Dist | Out-Null
Set-Content -Path (Join-Path $Bundle "package-kind") -Value "windows" -NoNewline
$Zip = Join-Path $Dist "$Project-$Version-windows-x64.zip"
if (Test-Path $Zip) { Remove-Item $Zip }
Compress-Archive -Path (Join-Path $Bundle "*") -DestinationPath $Zip
Write-Output "Wrote $Zip"
