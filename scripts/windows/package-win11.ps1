param(
    [ValidateSet("debug", "release")]
    [string] $Configuration = "release",
    [string] $OutputRoot = "",
    [switch] $SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$packagePath = Join-Path $repoRoot "Platforms/Windows/PeekabooWin11"

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repoRoot ".artifacts/windows"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputRoot)) {
    $OutputRoot = Join-Path $repoRoot $OutputRoot
}

$outputRootPath = [System.IO.Path]::GetFullPath($OutputRoot)
$stagingPath = Join-Path $outputRootPath "peekaboo-win11"
$zipPath = Join-Path $outputRootPath "peekaboo-win11.zip"
$checksumPath = "$zipPath.sha256"

if (-not (Test-Path $packagePath)) {
    throw "Windows package path not found: $packagePath"
}

if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
    throw "Swift is required to package peekaboo-win11."
}

Remove-Item $stagingPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item $checksumPath -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null

if (-not $SkipBuild) {
    swift build --package-path $packagePath -c $Configuration
}

$binPath = (swift build --package-path $packagePath -c $Configuration --show-bin-path).Trim()
$binaryPath = Join-Path $binPath "peekaboo-win11.exe"
if (-not (Test-Path $binaryPath)) {
    $binaryPath = Join-Path $binPath "peekaboo-win11"
}
if (-not (Test-Path $binaryPath)) {
    throw "Built peekaboo-win11 binary was not found under $binPath"
}

$packagedBinaryPath = Join-Path $stagingPath "peekaboo-win11.exe"
Copy-Item $binaryPath $packagedBinaryPath -Force
Copy-Item (Join-Path $repoRoot "LICENSE") (Join-Path $stagingPath "LICENSE") -Force

$gitSha = "unknown"
$gitShortSha = "unknown"
if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitSha = (git -C $repoRoot rev-parse HEAD).Trim()
    $gitShortSha = (git -C $repoRoot rev-parse --short HEAD).Trim()
}

$builtAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

@(
    "Peekaboo Windows 11 CLI",
    "Configuration: $Configuration",
    "Commit: $gitShortSha",
    "Built: $builtAt"
) | Set-Content -Path (Join-Path $stagingPath "BUILD_INFO.txt") -Encoding UTF8

$manifest = [ordered]@{
    schemaVersion = 1
    name = "peekaboo-win11"
    platform = "Windows"
    minimumSystemVersion = "Windows 11"
    nativeBackend = "Win32"
    configuration = $Configuration
    commit = $gitSha
    builtAt = $builtAt
    executable = "peekaboo-win11.exe"
    contents = @(
        "peekaboo-win11.exe",
        "LICENSE",
        "BUILD_INFO.txt",
        "README.md",
        "PACKAGE_MANIFEST.json"
    )
}

$manifest |
    ConvertTo-Json -Depth 4 |
    Set-Content -Path (Join-Path $stagingPath "PACKAGE_MANIFEST.json") -Encoding UTF8

@'
# Peekaboo Windows 11 CLI

This archive contains the standalone `peekaboo-win11.exe` binary built from the
native Windows 11 Swift package.

## Install

1. Extract this archive.
2. Add the extracted folder to `PATH`, or copy `peekaboo-win11.exe` to a folder
   already on `PATH`.
3. Run `peekaboo-win11.exe --help`.

## Examples

```powershell
.\peekaboo-win11.exe platform-info
.\peekaboo-win11.exe list displays
.\peekaboo-win11.exe capture screen --path .\screen.bmp
.\peekaboo-win11.exe capture frontmost --path .\frontmost.bmp
.\peekaboo-win11.exe input move --point 100,100
.\peekaboo-win11.exe automation status
.\peekaboo-win11.exe automation snapshot --scope foreground --max-depth 2 --max-elements 64
.\peekaboo-win11.exe automation element --scope root --index 0 --max-depth 0 --max-elements 1
```

See `docs/windows-11-refactor.md` in the source checkout for the full command
surface and current integration notes.
'@ | Set-Content -Path (Join-Path $stagingPath "README.md") -Encoding UTF8

Compress-Archive -Path (Join-Path $stagingPath "*") -DestinationPath $zipPath -Force
$zipHash = Get-FileHash -Algorithm SHA256 -Path $zipPath
$checksumLine = "{0}  {1}" -f $zipHash.Hash.ToLowerInvariant(), (Split-Path -Leaf $zipPath)
$checksumLine | Set-Content -Path $checksumPath -Encoding UTF8

Write-Host "Packaged peekaboo-win11:"
Write-Host "  Staging: $stagingPath"
Write-Host "  Archive: $zipPath"
Write-Host "  Checksum: $checksumPath"
