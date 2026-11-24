# Run this from the extracted MeterRead-Starter-main folder, in PowerShell.
# Flutter 3.47.7 must be available on PATH. This script never pushes to main.
$ErrorActionPreference = 'Stop'
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
dart format .
if ($LASTEXITCODE -ne 0) { throw 'dart format failed' }
dart run build_runner build --delete-conflicting-outputs
if ($LASTEXITCODE -ne 0) { throw 'Code generation failed' }
dart analyze --fatal-infos
if ($LASTEXITCODE -ne 0) { throw 'Analyzer failed' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Tests failed' }
Write-Host 'All local checks passed. Commit to your personal branch, not main.'
