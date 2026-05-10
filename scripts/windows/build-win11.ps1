Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$packagePath = Join-Path $repoRoot "Platforms/Windows/PeekabooWin11"

swift --version
swift package --package-path $packagePath describe
swift build --package-path $packagePath
swift test --package-path $packagePath
