param([string]$Zig = 'zig', [switch]$Verify, [string]$Python = 'python')
$ErrorActionPreference = 'Stop'
$buildRoot = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$hookSources = @('src/minhook/hook.c','src/minhook/buffer.c','src/minhook/trampoline.c','src/minhook/hde/hde64.c')
Push-Location $PSScriptRoot
try {
    & $Zig cc -target x86_64-windows-gnu -shared -O2 -Isrc -Isrc/minhook 'src/re2_legacy_native.c' @hookSources -o 'build/re2_legacy_native.dll'
    if ($LASTEXITCODE -ne 0) { throw 'Native DLL compilation failed.' }
    if ($Verify) {
        & $Python 'tests/test_plugin.py'
        if ($LASTEXITCODE -ne 0) { throw 'Lua behavior checks failed.' }
        & $Zig cc -target x86_64-windows-gnu -O2 -Isrc -Isrc/minhook 'tests/test_native_actions.c' @hookSources -o 'build/test_native_actions.exe'
        if ($LASTEXITCODE -ne 0) { throw 'Native action fixture compilation failed.' }
        & $Zig cc -target x86_64-windows-gnu -O2 -Isrc 'tests/test_native_abi.c' -o 'build/test_native_abi.exe'
        if ($LASTEXITCODE -ne 0) { throw 'Native ABI fixture compilation failed.' }
        Push-Location $buildRoot
        try {
            & '.\test_native_actions.exe'
            if ($LASTEXITCODE -ne 0) { throw 'Native action checks failed.' }
            & '.\test_native_abi.exe'
            if ($LASTEXITCODE -ne 0) { throw 'Native ABI checks failed.' }
        } finally { Pop-Location }
    }
    Write-Output 'Build completed. Outputs are in build/. The released helper binary is retained in reframework/plugins/.'
} finally { Pop-Location }
