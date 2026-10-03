param([string]$GameDirectory = 'D:\SteamLibrary\steamapps\common\RESIDENT EVIL 2  BIOHAZARD RE2')
$ErrorActionPreference = 'Stop'
$gameRoot = (Resolve-Path -LiteralPath $GameDirectory).Path
$gameExe = Join-Path $gameRoot 're2.exe'
if (-not (Test-Path -LiteralPath $gameExe)) { throw 'This is not the RE2 game directory.' }
if (Get-Process -Name re2 -ErrorAction SilentlyContinue) { throw 'Close RE2 before installing so both plugin files can be replaced together.' }
$expectedHash = '6CAAA815BF9E95F8A841BC81FDF29FEC55E836C87BAB8A76D55C69BEF9ADA941'
if ((Get-FileHash -LiteralPath $gameExe -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'The game executable differs from the verified build. Recheck compatibility before installation.'
}
if (-not (Test-Path -LiteralPath (Join-Path $gameRoot 'dinput8.dll'))) { throw 'REFramework is not installed.' }
$relativeFiles = @('reframework\autorun\re2_legacy_trainer.lua', 'reframework\plugins\re2_legacy_native.dll')
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
foreach ($relativeFile in $relativeFiles) {
    $sourceFile = Join-Path $PSScriptRoot $relativeFile
    $manifestKey = $relativeFile.Replace('\', '/')
    $packageHash = $manifest.files.$manifestKey
    if (-not $packageHash -or -not (Test-Path -LiteralPath $sourceFile)) { throw "Incomplete package: $relativeFile" }
    if ((Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash -ne $packageHash) { throw "Package verification failed: $relativeFile" }
}
$backupRoot = Join-Path $gameRoot ('reframework\legacy_backup\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
foreach ($relativeFile in $relativeFiles) {
    $sourceFile = Join-Path $PSScriptRoot $relativeFile
    $destinationFile = Join-Path $gameRoot $relativeFile
    if (-not (Test-Path -LiteralPath $sourceFile)) { throw "Missing package file: $relativeFile" }
    if (Test-Path -LiteralPath $destinationFile) {
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        Copy-Item -LiteralPath $destinationFile -Destination (Join-Path $backupRoot (Split-Path $destinationFile -Leaf))
    }
    New-Item -ItemType Directory -Path (Split-Path $destinationFile -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $sourceFile -Destination $destinationFile -Force
    if ((Get-FileHash -LiteralPath $sourceFile).Hash -ne (Get-FileHash -LiteralPath $destinationFile).Hash) { throw "Copy verification failed: $relativeFile" }
}
$systemFont = Join-Path ([Environment]::GetFolderPath('Fonts')) 'msyh.ttc'
if (Test-Path -LiteralPath $systemFont) {
    $fontFolder = Join-Path $gameRoot 'reframework\fonts'
    New-Item -ItemType Directory -Path $fontFolder -Force | Out-Null
    Copy-Item -LiteralPath $systemFont -Destination (Join-Path $fontFolder 're2_legacy_font.ttc') -Force
}
Write-Output 'Installed and verified both files. Restart the game, press Insert, and open Script Generated UI > RE2 Legacy Trainer. Saved switches and settings are restored; Reset Settings disables all features.'
