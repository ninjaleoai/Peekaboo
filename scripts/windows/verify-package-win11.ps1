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

$platformOutput = & $executablePath platform-info 2>&1
$platformExitCode = $LASTEXITCODE
if ($platformExitCode -ne 0) {
    throw "Packaged peekaboo-win11.exe platform-info exited with $platformExitCode. Output: $platformOutput"
}

$platformText = $platformOutput -join "`n"
try {
    $platformEnvelope = $platformText | ConvertFrom-Json
} catch {
    throw "Packaged platform-info output was not valid JSON. Output: $platformText"
}

if ($platformEnvelope.ok -ne $true) {
    throw "Packaged platform-info did not return ok=true. Output: $platformText"
}
if ($platformEnvelope.data.name -ne "Windows") {
    throw "Packaged platform-info returned unexpected platform name: $($platformEnvelope.data.name)"
}
if ($platformEnvelope.data.minimumSystemVersion -ne "Windows 11") {
    $version = $platformEnvelope.data.minimumSystemVersion
    throw "Packaged platform-info returned unexpected minimum system version: $version"
}
if ($platformEnvelope.data.nativeBackend -ne "Win32") {
    throw "Packaged platform-info returned unexpected native backend: $($platformEnvelope.data.nativeBackend)"
}

$platformCapabilities = @($platformEnvelope.data.capabilities)
if (-not ($platformCapabilities -contains "captureScreenBMP")) {
    throw "Packaged platform-info did not advertise BMP screen capture."
}
if (-not ($platformCapabilities -contains "inspectUIAutomation")) {
    throw "Packaged platform-info did not advertise UI Automation inspection."
}

$screenCapturePath = Join-Path $verifyPath "screen-smoke.bmp"
Remove-Item $screenCapturePath -Force -ErrorAction SilentlyContinue
$captureOutput = & $executablePath capture screen --path $screenCapturePath 2>&1
$captureExitCode = $LASTEXITCODE
if ($captureExitCode -ne 0) {
    throw "Packaged peekaboo-win11.exe capture screen exited with $captureExitCode. Output: $captureOutput"
}

$captureText = $captureOutput -join "`n"
try {
    $captureEnvelope = $captureText | ConvertFrom-Json
} catch {
    throw "Packaged capture screen output was not valid JSON. Output: $captureText"
}

if ($captureEnvelope.ok -ne $true) {
    throw "Packaged capture screen did not return ok=true. Output: $captureText"
}
if ($captureEnvelope.data.format -ne "bmp") {
    throw "Packaged capture screen returned unexpected format: $($captureEnvelope.data.format)"
}
if ($captureEnvelope.data.captureMethod -ne "gdiRegion") {
    $method = $captureEnvelope.data.captureMethod
    throw "Packaged capture screen returned unexpected capture method: $method"
}
if (-not (Test-Path $screenCapturePath)) {
    throw "Packaged capture screen did not write $screenCapturePath."
}

$screenCaptureSize = (Get-Item $screenCapturePath).Length
if ($screenCaptureSize -le 54) {
    throw "Packaged capture screen wrote an invalid BMP-sized file: $screenCaptureSize bytes."
}
if ([int64] $captureEnvelope.data.byteCount -ne $screenCaptureSize) {
    $byteCount = $captureEnvelope.data.byteCount
    throw "Packaged capture byteCount $byteCount did not match file size $screenCaptureSize."
}

$automationOutput = & $executablePath automation status 2>&1
$automationExitCode = $LASTEXITCODE
if ($automationExitCode -ne 0) {
    throw "Packaged peekaboo-win11.exe automation status exited with $automationExitCode. Output: $automationOutput"
}

$automationText = $automationOutput -join "`n"
try {
    $automationEnvelope = $automationText | ConvertFrom-Json
} catch {
    throw "Packaged automation status output was not valid JSON. Output: $automationText"
}

if ($automationEnvelope.ok -ne $true) {
    throw "Packaged automation status did not return ok=true. Output: $automationText"
}
if ($automationEnvelope.data.nativeBackend -ne "UIAutomation") {
    $backend = $automationEnvelope.data.nativeBackend
    throw "Packaged automation status returned unexpected native backend: $backend"
}
if ($automationEnvelope.data.isAvailable -ne $true) {
    $errorMessage = $automationEnvelope.data.error
    throw "Packaged automation status did not report UIA availability. Error: $errorMessage"
}
if ($automationEnvelope.data.rootElementAvailable -ne $true) {
    $errorMessage = $automationEnvelope.data.error
    throw "Packaged automation status did not report root availability. Error: $errorMessage"
}

Write-Host "Verified peekaboo-win11 package:"
Write-Host "  Archive: $zipPath"
Write-Host "  Checksum: $checksumPath"
Write-Host "  Extracted: $verifyPath"
Write-Host "  Screen capture: $screenCapturePath"
Write-Host "  UI Automation: available"
