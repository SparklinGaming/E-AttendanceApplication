# Run Dart analyzer, apply fixes, and format the code
# Usage: .\analyze_and_fix.ps1

$ErrorActionPreference = 'Stop'

Write-Host "Running dart analyze..."
dart analyze

Write-Host "Applying dart fixes..."
dart fix --apply

Write-Host "Formatting Dart files..."
dart format .

Write-Host "Done."