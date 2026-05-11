param(
    [string] $ArtifactRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

if ([string]::IsNullOrWhiteSpace($ArtifactRoot)) {
    $ArtifactRoot = Join-Path $repoRoot ".artifacts/windows"
} elseif (-not [System.IO.Path]::IsPathRooted($ArtifactRoot)) {
    $ArtifactRoot = Join-Path $repoRoot $ArtifactRoot
}

$artifactRootPath = [System.IO.Path]::GetFullPath($ArtifactRoot)
$zipPath = Join-Path $artifactRootPath "peekaboo-win11.zip"
$checksumPath = "$zipPath.sha256"
$verifyPath = Join-Path $artifactRootPath "verify-package"

if (-not (Test-Path $zipPath)) {
    throw "Package archive not found: $zipPath"
}

if (-not (Test-Path $checksumPath)) {
    throw "Package checksum not found: $checksumPath"
}

$checksumParts = (Get-Content -Raw -Path $checksumPath).Trim() -split "\s+", 2
if ($checksumParts.Count -ne 2) {
    throw "Checksum file must contain '<sha256>  peekaboo-win11.zip'."
}

$expectedHash = $checksumParts[0].ToLowerInvariant()
$expectedFileName = $checksumParts[1].Trim()
if ($expectedFileName -ne "peekaboo-win11.zip") {
    throw "Checksum file references '$expectedFileName', expected 'peekaboo-win11.zip'."
}

$actualHash = (Get-FileHash -Algorithm SHA256 -Path $zipPath).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) {
    throw "Package checksum mismatch. Expected $expectedHash but found $actualHash."
}

Remove-Item $verifyPath -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $verifyPath -Force | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $verifyPath -Force

$requiredFiles = @(
    "peekaboo-win11.exe",
    "LICENSE",
    "BUILD_INFO.txt",
    "README.md"
)

foreach ($fileName in $requiredFiles) {
    $filePath = Join-Path $verifyPath $fileName
    if (-not (Test-Path $filePath)) {
        throw "Package archive is missing $fileName."
    }
}

$executablePath = Join-Path $verifyPath "peekaboo-win11.exe"
if ((Get-Item $executablePath).Length -le 0) {
    throw "Packaged peekaboo-win11.exe is empty."
}

$helpOutput = & $executablePath --help 2>&1
$helpExitCode = $LASTEXITCODE
if ($helpExitCode -ne 0) {
    throw "Packaged peekaboo-win11.exe --help exited with $helpExitCode. Output: $helpOutput"
}

$helpText = $helpOutput -join "`n"
if (-not $helpText.Contains("peekaboo-win11")) {
    throw "Packaged help output did not include the command name."
}
if (-not $helpText.Contains("capture screen --path")) {
    throw "Packaged help output did not include the capture command surface."
}
if (-not $helpText.Contains("automation snapshot")) {
    throw "Packaged help output did not include the automation command surface."
}

Write-Host "Verified peekaboo-win11 package:"
Write-Host "  Archive: $zipPath"
Write-Host "  Checksum: $checksumPath"
Write-Host "  Extracted: $verifyPath"
