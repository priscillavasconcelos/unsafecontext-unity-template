#Requires -Version 5.1
<#
.SYNOPSIS
    Clean-removes the AI Game Developer (com.ivanmurzak.unity.mcp) Unity package
    and reinstalls it via the official CLI from https://ai-game.dev/download.

.DESCRIPTION
    Drop this script into any Unity project root and run it. Performs:
      1. Deletes Assets/Plugins/NuGet (and its .meta).
      2. Removes com.ivanmurzak.unity.mcp from Packages/manifest.json dependencies.
      3. Removes the related scoped-registry scopes (com.ivanmurzak,
         org.nuget.com.ivanmurzak, org.nuget.microsoft, org.nuget.system,
         org.nuget.r3); removes the registry entry entirely if no scopes remain.
      4. Removes com.ivanmurzak.unity.mcp from Packages/packages-lock.json.
      5. Deletes Library/PackageCache/com.ivanmurzak.unity.mcp@*.
      6. Reinstalls via `npx unity-mcp-cli install-plugin <project>`.

    Close Unity before running. Open Unity afterward to reimport.

.PARAMETER ProjectPath
    Unity project root. Defaults to the current directory.

.PARAMETER SkipInstall
    Only clean; skip the reinstall step.

.EXAMPLE
    .\CleanUpdate-AIGameDeveloper.ps1
    .\CleanUpdate-AIGameDeveloper.ps1 -ProjectPath D:\Path\To\OtherUnityProject
    .\CleanUpdate-AIGameDeveloper.ps1 -SkipInstall
#>

[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'

$packageId = 'com.ivanmurzak.unity.mcp'
$scopesToRemove = @(
    'com.ivanmurzak',
    'org.nuget.com.ivanmurzak',
    'org.nuget.microsoft',
    'org.nuget.system',
    'org.nuget.r3'
)

$ProjectPath  = (Resolve-Path $ProjectPath).Path
$nugetFolder  = Join-Path $ProjectPath 'Assets\Plugins\NuGet'
$nugetMeta    = Join-Path $ProjectPath 'Assets\Plugins\NuGet.meta'
$manifestPath = Join-Path $ProjectPath 'Packages\manifest.json'
$lockPath     = Join-Path $ProjectPath 'Packages\packages-lock.json'
$packageCache = Join-Path $ProjectPath 'Library\PackageCache'

if (-not (Test-Path $manifestPath)) {
    throw "manifest.json not found at $manifestPath. Pass -ProjectPath <unity project root>."
}

Write-Host "Project: $ProjectPath" -ForegroundColor Cyan

function Write-JsonFile {
    param([string]$Path, $Object)
    $json = $Object | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# 1. Remove Assets/Plugins/NuGet folder + meta
foreach ($p in @($nugetFolder, $nugetMeta)) {
    if (Test-Path $p) {
        Write-Host "Removing $p"
        Remove-Item $p -Recurse -Force -Confirm:$false
    } else {
        Write-Host "Skip (not present): $p"
    }
}

# 2 & 3. Edit Packages/manifest.json
Write-Host "Updating $manifestPath"
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

if ($manifest.dependencies -and ($manifest.dependencies.PSObject.Properties.Name -contains $packageId)) {
    $manifest.dependencies.PSObject.Properties.Remove($packageId)
    Write-Host "  - removed dependency '$packageId'"
}

if (($manifest.PSObject.Properties.Name -contains 'scopedRegistries') -and $manifest.scopedRegistries) {
    $keptRegistries = [System.Collections.Generic.List[object]]::new()
    foreach ($reg in $manifest.scopedRegistries) {
        $keptScopes = [System.Collections.Generic.List[string]]::new()
        foreach ($s in $reg.scopes) {
            if ($scopesToRemove -notcontains $s) { $keptScopes.Add($s) }
        }
        if ($keptScopes.Count -eq 0) {
            Write-Host "  - removed empty scoped registry '$($reg.name)'"
            continue
        }
        if ($keptScopes.Count -ne @($reg.scopes).Count) {
            Write-Host "  - trimmed scopes on '$($reg.name)'"
        }
        $reg.scopes = $keptScopes
        $keptRegistries.Add($reg)
    }
    if ($keptRegistries.Count -eq 0) {
        $manifest.PSObject.Properties.Remove('scopedRegistries')
    } else {
        $manifest.scopedRegistries = $keptRegistries
    }
}

Write-JsonFile -Path $manifestPath -Object $manifest

# 4. Edit Packages/packages-lock.json
if (Test-Path $lockPath) {
    Write-Host "Updating $lockPath"
    $lock = Get-Content $lockPath -Raw | ConvertFrom-Json
    if ($lock.dependencies -and ($lock.dependencies.PSObject.Properties.Name -contains $packageId)) {
        $lock.dependencies.PSObject.Properties.Remove($packageId)
        Write-JsonFile -Path $lockPath -Object $lock
        Write-Host "  - removed lock entry '$packageId'"
    }
}

# 5. Library/PackageCache/com.ivanmurzak.unity.mcp@*
if (Test-Path $packageCache) {
    Get-ChildItem -Path $packageCache -Directory -Filter "$packageId@*" -ErrorAction SilentlyContinue |
        ForEach-Object {
            Write-Host "Removing cached package $($_.FullName)"
            Remove-Item $_.FullName -Recurse -Force -Confirm:$false
        }
}

Write-Host ""
Write-Host "Clean complete." -ForegroundColor Green

# 6. Reinstall via official CLI (https://ai-game.dev/download)
if ($SkipInstall) {
    Write-Host "Skipping reinstall (-SkipInstall)." -ForegroundColor Yellow
    return
}

$npx = Get-Command npx -ErrorAction SilentlyContinue
if (-not $npx) {
    Write-Host "npx not found on PATH. Install Node.js, then run: npx unity-mcp-cli install-plugin `"$ProjectPath`"" -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "Resolving latest plugin version from OpenUPM..." -ForegroundColor Cyan
$latestVersion = $null
try {
    $resp = Invoke-WebRequest -Uri "https://package.openupm.com/$packageId" -UseBasicParsing -TimeoutSec 30
    $latestVersion = ($resp.Content | ConvertFrom-Json).'dist-tags'.latest
} catch {
    Write-Host "  - OpenUPM lookup failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
if ($latestVersion) {
    Write-Host "Installing AI Game Developer plugin v$latestVersion via unity-mcp-cli..." -ForegroundColor Cyan
    & npx --yes unity-mcp-cli install-plugin $ProjectPath --plugin-version $latestVersion
} else {
    Write-Host "Installing latest AI Game Developer plugin via unity-mcp-cli (CLI auto-resolve)..." -ForegroundColor Cyan
    & npx --yes unity-mcp-cli install-plugin $ProjectPath
}
if ($LASTEXITCODE -ne 0) {
    throw "unity-mcp-cli install-plugin failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "Done. Open Unity to reimport." -ForegroundColor Green
