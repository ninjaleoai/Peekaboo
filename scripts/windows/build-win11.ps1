Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$packagePath = Join-Path $repoRoot "Platforms/Windows/PeekabooWin11"
$desktopPackagePath = Join-Path $repoRoot "Core/PeekabooDesktop"

swift --version
swift package --package-path $desktopPackagePath describe
swift test --package-path $desktopPackagePath
swift package --package-path $packagePath describe
swift build --package-path $packagePath
swift test --package-path $packagePath
