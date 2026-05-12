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
    "README.md",
    "PACKAGE_MANIFEST.json"
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

$manifestPath = Join-Path $verifyPath "PACKAGE_MANIFEST.json"
try {
    $manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
} catch {
    throw "Package manifest was not valid JSON: $manifestPath"
}

if ($manifest.schemaVersion -ne 1) {
    throw "Package manifest returned unexpected schemaVersion: $($manifest.schemaVersion)"
}
if ($manifest.name -ne "peekaboo-win11") {
    throw "Package manifest returned unexpected name: $($manifest.name)"
}
if ($manifest.platform -ne "Windows") {
    throw "Package manifest returned unexpected platform: $($manifest.platform)"
}
if ($manifest.minimumSystemVersion -ne "Windows 11") {
    $version = $manifest.minimumSystemVersion
    throw "Package manifest returned unexpected minimum system version: $version"
}
if ($manifest.nativeBackend -ne "Win32") {
    throw "Package manifest returned unexpected native backend: $($manifest.nativeBackend)"
}
if ($manifest.executable -ne "peekaboo-win11.exe") {
    throw "Package manifest returned unexpected executable: $($manifest.executable)"
}
if ([string]::IsNullOrWhiteSpace($manifest.commit)) {
    throw "Package manifest did not include a commit."
}
if ([string]::IsNullOrWhiteSpace($manifest.builtAt)) {
    throw "Package manifest did not include a build timestamp."
}

$manifestContents = @($manifest.contents)
$archiveFiles = @(Get-ChildItem -Path $verifyPath -File | ForEach-Object { $_.Name })
foreach ($fileName in $manifestContents) {
    $filePath = Join-Path $verifyPath $fileName
    if (-not (Test-Path $filePath)) {
        throw "Package manifest contents listed missing file $fileName."
    }
}
foreach ($fileName in $archiveFiles) {
    if (-not ($manifestContents -contains $fileName)) {
        throw "Package manifest contents did not include archive file $fileName."
    }
}
if ($manifestContents.Count -ne $archiveFiles.Count) {
    $manifestCount = $manifestContents.Count
    $archiveCount = $archiveFiles.Count
    throw "Package manifest listed $manifestCount files but archive contained $archiveCount files."
}

function Invoke-PackagedJsonCommand {
    param(
        [string] $Description,
        [string[]] $Arguments
    )

    $commandOutput = & $executablePath @Arguments 2>&1
    $commandExitCode = $LASTEXITCODE
    if ($commandExitCode -ne 0) {
        throw "Packaged peekaboo-win11.exe $Description exited with $commandExitCode. Output: $commandOutput"
    }

    $commandText = $commandOutput -join "`n"
    try {
        $commandEnvelope = $commandText | ConvertFrom-Json
    } catch {
        throw "Packaged $Description output was not valid JSON. Output: $commandText"
    }

    [PSCustomObject]@{
        Envelope = $commandEnvelope
        Text = $commandText
    }
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

$displayList = Invoke-PackagedJsonCommand `
    -Description "list displays" `
    -Arguments @("list", "displays")
if ($displayList.Envelope.ok -ne $true) {
    throw "Packaged list displays did not return ok=true. Output: $($displayList.Text)"
}

$displays = @($displayList.Envelope.data)
if ($displays.Count -lt 1) {
    throw "Packaged list displays did not return any displays. Output: $($displayList.Text)"
}
if ($displays[0].bounds.width -le 0 -or $displays[0].bounds.height -le 0) {
    throw "Packaged list displays returned invalid display bounds. Output: $($displayList.Text)"
}

$windowList = Invoke-PackagedJsonCommand `
    -Description "list windows --include-invisible" `
    -Arguments @("list", "windows", "--include-invisible")
if ($windowList.Envelope.ok -ne $true) {
    throw "Packaged list windows did not return ok=true. Output: $($windowList.Text)"
}
if ($null -eq $windowList.Envelope.PSObject.Properties["data"]) {
    throw "Packaged list windows did not include a data field. Output: $($windowList.Text)"
}

$visibleWindowList = Invoke-PackagedJsonCommand `
    -Description "list windows" `
    -Arguments @("list", "windows")
if ($visibleWindowList.Envelope.ok -ne $true) {
    throw "Packaged list visible windows did not return ok=true. Output: $($visibleWindowList.Text)"
}

$visibleWindows = @($visibleWindowList.Envelope.data)
$captureWindow = $visibleWindows |
    Where-Object {
        $_.isVisible -eq $true -and
        $_.isMinimized -ne $true -and
        $_.bounds.width -gt 0 -and
        $_.bounds.height -gt 0
    } |
    Select-Object -First 1
if ($null -eq $captureWindow) {
    throw "Packaged list windows did not return a visible non-minimized capture candidate."
}

$appList = Invoke-PackagedJsonCommand `
    -Description "list apps" `
    -Arguments @("list", "apps")
if ($appList.Envelope.ok -ne $true) {
    throw "Packaged list apps did not return ok=true. Output: $($appList.Text)"
}
if ($null -eq $appList.Envelope.PSObject.Properties["data"]) {
    throw "Packaged list apps did not include a data field. Output: $($appList.Text)"
}

$cursorPosition = Invoke-PackagedJsonCommand `
    -Description "input position" `
    -Arguments @("input", "position")
if ($cursorPosition.Envelope.ok -ne $true) {
    throw "Packaged input position did not return ok=true. Output: $($cursorPosition.Text)"
}

$cursorData = $cursorPosition.Envelope.data
if ($null -eq $cursorData.PSObject.Properties["x"] -or
    $null -eq $cursorData.PSObject.Properties["y"])
{
    throw "Packaged input position did not include x/y coordinates. Output: $($cursorPosition.Text)"
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

$areaCapturePath = Join-Path $verifyPath "area-smoke.bmp"
$areaX = [int] $displays[0].bounds.x
$areaY = [int] $displays[0].bounds.y
$areaWidth = [Math]::Min(10, [int] $displays[0].bounds.width)
$areaHeight = [Math]::Min(10, [int] $displays[0].bounds.height)
$areaRect = "$areaX,$areaY,$areaWidth,$areaHeight"
Remove-Item $areaCapturePath -Force -ErrorAction SilentlyContinue
$areaOutput = & $executablePath capture area --rect $areaRect --path $areaCapturePath 2>&1
$areaExitCode = $LASTEXITCODE
if ($areaExitCode -ne 0) {
    throw "Packaged peekaboo-win11.exe capture area exited with $areaExitCode. Output: $areaOutput"
}

$areaText = $areaOutput -join "`n"
try {
    $areaEnvelope = $areaText | ConvertFrom-Json
} catch {
    throw "Packaged capture area output was not valid JSON. Output: $areaText"
}

if ($areaEnvelope.ok -ne $true) {
    throw "Packaged capture area did not return ok=true. Output: $areaText"
}
if ($areaEnvelope.data.format -ne "bmp") {
    throw "Packaged capture area returned unexpected format: $($areaEnvelope.data.format)"
}
if ($areaEnvelope.data.captureMethod -ne "gdiRegion") {
    $method = $areaEnvelope.data.captureMethod
    throw "Packaged capture area returned unexpected capture method: $method"
}
if ($areaEnvelope.data.bounds.x -ne $areaX -or
    $areaEnvelope.data.bounds.y -ne $areaY -or
    $areaEnvelope.data.bounds.width -ne $areaWidth -or
    $areaEnvelope.data.bounds.height -ne $areaHeight)
{
    throw "Packaged capture area returned unexpected bounds. Output: $areaText"
}
if (-not (Test-Path $areaCapturePath)) {
    throw "Packaged capture area did not write $areaCapturePath."
}

$areaCaptureSize = (Get-Item $areaCapturePath).Length
if ($areaCaptureSize -le 54) {
    throw "Packaged capture area wrote an invalid BMP-sized file: $areaCaptureSize bytes."
}
if ([int64] $areaEnvelope.data.byteCount -ne $areaCaptureSize) {
    $byteCount = $areaEnvelope.data.byteCount
    throw "Packaged area byteCount $byteCount did not match file size $areaCaptureSize."
}

$windowCapturePath = Join-Path $verifyPath "window-smoke.bmp"
$windowId = [string] $captureWindow.windowIdentifier
Remove-Item $windowCapturePath -Force -ErrorAction SilentlyContinue
$windowOutput = & $executablePath capture window --id $windowId --path $windowCapturePath 2>&1
$windowExitCode = $LASTEXITCODE
if ($windowExitCode -ne 0) {
    throw "Packaged peekaboo-win11.exe capture window exited with $windowExitCode. Output: $windowOutput"
}

$windowText = $windowOutput -join "`n"
try {
    $windowEnvelope = $windowText | ConvertFrom-Json
} catch {
    throw "Packaged capture window output was not valid JSON. Output: $windowText"
}

if ($windowEnvelope.ok -ne $true) {
    throw "Packaged capture window did not return ok=true. Output: $windowText"
}
if ($windowEnvelope.data.format -ne "bmp") {
    throw "Packaged capture window returned unexpected format: $($windowEnvelope.data.format)"
}
if (-not (@("gdiRegion", "printWindow") -contains $windowEnvelope.data.captureMethod)) {
    $method = $windowEnvelope.data.captureMethod
    throw "Packaged capture window returned unexpected capture method: $method"
}
if ($windowEnvelope.data.bounds.x -ne $captureWindow.bounds.x -or
    $windowEnvelope.data.bounds.y -ne $captureWindow.bounds.y -or
    $windowEnvelope.data.bounds.width -ne $captureWindow.bounds.width -or
    $windowEnvelope.data.bounds.height -ne $captureWindow.bounds.height)
{
    throw "Packaged capture window returned unexpected bounds. Output: $windowText"
}
if (-not (Test-Path $windowCapturePath)) {
    throw "Packaged capture window did not write $windowCapturePath."
}

$windowCaptureSize = (Get-Item $windowCapturePath).Length
if ($windowCaptureSize -le 54) {
    throw "Packaged capture window wrote an invalid BMP-sized file: $windowCaptureSize bytes."
}
if ([int64] $windowEnvelope.data.byteCount -ne $windowCaptureSize) {
    $byteCount = $windowEnvelope.data.byteCount
    throw "Packaged window byteCount $byteCount did not match file size $windowCaptureSize."
}

$frontmostCapturePath = Join-Path $verifyPath "frontmost-smoke.bmp"
Remove-Item $frontmostCapturePath -Force -ErrorAction SilentlyContinue
$frontmostOutput = & $executablePath capture frontmost --path $frontmostCapturePath 2>&1
$frontmostExitCode = $LASTEXITCODE
if ($frontmostExitCode -ne 0) {
    throw "Packaged peekaboo-win11.exe capture frontmost exited with $frontmostExitCode. Output: $frontmostOutput"
}

$frontmostText = $frontmostOutput -join "`n"
try {
    $frontmostEnvelope = $frontmostText | ConvertFrom-Json
} catch {
    throw "Packaged capture frontmost output was not valid JSON. Output: $frontmostText"
}

if ($frontmostEnvelope.ok -ne $true) {
    throw "Packaged capture frontmost did not return ok=true. Output: $frontmostText"
}
if ($frontmostEnvelope.data.format -ne "bmp") {
    $format = $frontmostEnvelope.data.format
    throw "Packaged capture frontmost returned unexpected format: $format"
}
if (-not (@("gdiRegion", "printWindow") -contains $frontmostEnvelope.data.captureMethod)) {
    $method = $frontmostEnvelope.data.captureMethod
    throw "Packaged capture frontmost returned unexpected capture method: $method"
}
if ($frontmostEnvelope.data.bounds.width -le 0 -or
    $frontmostEnvelope.data.bounds.height -le 0)
{
    throw "Packaged capture frontmost returned invalid bounds. Output: $frontmostText"
}
if (-not (Test-Path $frontmostCapturePath)) {
    throw "Packaged capture frontmost did not write $frontmostCapturePath."
}

$frontmostCaptureSize = (Get-Item $frontmostCapturePath).Length
if ($frontmostCaptureSize -le 54) {
    $size = $frontmostCaptureSize
    throw "Packaged capture frontmost wrote an invalid BMP-sized file: $size bytes."
}
if ([int64] $frontmostEnvelope.data.byteCount -ne $frontmostCaptureSize) {
    $byteCount = $frontmostEnvelope.data.byteCount
    throw "Packaged frontmost byteCount $byteCount did not match file size $frontmostCaptureSize."
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

$snapshotOutput = & $executablePath automation snapshot --scope root --max-depth 0 --max-elements 1 2>&1
$snapshotExitCode = $LASTEXITCODE
if ($snapshotExitCode -ne 0) {
    throw "Packaged peekaboo-win11.exe automation snapshot exited with $snapshotExitCode. Output: $snapshotOutput"
}

$snapshotText = $snapshotOutput -join "`n"
try {
    $snapshotEnvelope = $snapshotText | ConvertFrom-Json
} catch {
    throw "Packaged automation snapshot output was not valid JSON. Output: $snapshotText"
}

if ($snapshotEnvelope.ok -ne $true) {
    throw "Packaged automation snapshot did not return ok=true. Output: $snapshotText"
}
if ($snapshotEnvelope.data.nativeBackend -ne "UIAutomation") {
    $backend = $snapshotEnvelope.data.nativeBackend
    throw "Packaged automation snapshot returned unexpected native backend: $backend"
}
if ($snapshotEnvelope.data.scope -ne "root") {
    throw "Packaged automation snapshot returned unexpected scope: $($snapshotEnvelope.data.scope)"
}
if ($snapshotEnvelope.data.maxDepth -ne 0) {
    throw "Packaged automation snapshot returned unexpected maxDepth: $($snapshotEnvelope.data.maxDepth)"
}
if ($snapshotEnvelope.data.maxElements -ne 1) {
    throw "Packaged automation snapshot returned unexpected maxElements: $($snapshotEnvelope.data.maxElements)"
}
$snapshotError = $null
$snapshotErrorProperty = $snapshotEnvelope.data.PSObject.Properties["error"]
if ($null -ne $snapshotErrorProperty) {
    $snapshotError = $snapshotErrorProperty.Value
}
if (-not [string]::IsNullOrEmpty($snapshotError)) {
    throw "Packaged automation snapshot returned an error: $snapshotError"
}
if ($snapshotEnvelope.data.elementCount -lt 1) {
    throw "Packaged automation snapshot did not return any elements. Output: $snapshotText"
}

$snapshotElements = @($snapshotEnvelope.data.elements)
if ($snapshotElements.Count -lt 1) {
    throw "Packaged automation snapshot returned no element payloads. Output: $snapshotText"
}
if ($snapshotElements[0].index -ne 0) {
    throw "Packaged automation snapshot first element had unexpected index: $($snapshotElements[0].index)"
}
if ($snapshotElements[0].depth -ne 0) {
    throw "Packaged automation snapshot first element had unexpected depth: $($snapshotElements[0].depth)"
}

$elementOutput = & $executablePath automation element --scope root --index 0 --max-depth 0 --max-elements 1 2>&1
$elementExitCode = $LASTEXITCODE
if ($elementExitCode -ne 0) {
    throw "Packaged peekaboo-win11.exe automation element exited with $elementExitCode. Output: $elementOutput"
}

$elementText = $elementOutput -join "`n"
try {
    $elementEnvelope = $elementText | ConvertFrom-Json
} catch {
    throw "Packaged automation element output was not valid JSON. Output: $elementText"
}

if ($elementEnvelope.ok -ne $true) {
    throw "Packaged automation element did not return ok=true. Output: $elementText"
}
if ($elementEnvelope.data.nativeBackend -ne "UIAutomation") {
    $backend = $elementEnvelope.data.nativeBackend
    throw "Packaged automation element returned unexpected native backend: $backend"
}
if ($elementEnvelope.data.scope -ne "root") {
    throw "Packaged automation element returned unexpected scope: $($elementEnvelope.data.scope)"
}
if ($elementEnvelope.data.maxDepth -ne 0) {
    throw "Packaged automation element returned unexpected maxDepth: $($elementEnvelope.data.maxDepth)"
}
if ($elementEnvelope.data.maxElements -ne 1) {
    throw "Packaged automation element returned unexpected maxElements: $($elementEnvelope.data.maxElements)"
}
if ($elementEnvelope.data.elementCount -lt 1) {
    throw "Packaged automation element did not report any available elements. Output: $elementText"
}
if ($elementEnvelope.data.elementIndex -ne 0) {
    throw "Packaged automation element returned unexpected elementIndex: $($elementEnvelope.data.elementIndex)"
}
if ($elementEnvelope.data.element.index -ne 0) {
    throw "Packaged automation element payload had unexpected index: $($elementEnvelope.data.element.index)"
}
if ($elementEnvelope.data.element.depth -ne 0) {
    throw "Packaged automation element payload had unexpected depth: $($elementEnvelope.data.element.depth)"
}

Write-Host "Verified peekaboo-win11 package:"
Write-Host "  Archive: $zipPath"
Write-Host "  Checksum: $checksumPath"
Write-Host "  Extracted: $verifyPath"
Write-Host "  Manifest: $manifestPath"
Write-Host "  Desktop state: displays, windows, apps"
Write-Host "  Cursor position: readable"
Write-Host "  Screen capture: $screenCapturePath"
Write-Host "  Area capture: $areaCapturePath"
Write-Host "  Window capture: $windowCapturePath"
Write-Host "  Frontmost capture: $frontmostCapturePath"
Write-Host "  UI Automation: available"
Write-Host "  UI Automation snapshot: root"
Write-Host "  UI Automation element lookup: root index 0"
