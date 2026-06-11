$ErrorActionPreference = "Stop"

$HomeDir = [Environment]::GetFolderPath("UserProfile")
$ConfigDir = Join-Path $HomeDir ".mimoclaude"
$ConfigFile = Join-Path $ConfigDir "config"
$BinDir = Join-Path $HomeDir "bin"
$CommandPs1 = Join-Path $BinDir "mimoclaude.ps1"
$CommandCmd = Join-Path $BinDir "mimoclaude.cmd"
$TokenPlanBaseUrl = "https://token-plan-sgp.xiaomimimo.com/anthropic"

function Read-PlainTextSecret {
    param(
        [string]$Prompt
    )

    $SecureValue = Read-Host $Prompt -AsSecureString
    $Pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)

    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Pointer)
    }
}

function Protect-ConfigFile {
    param(
        [string]$Path
    )

    try {
        $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $Rights = [System.Security.AccessControl.FileSystemRights]::FullControl
        $AccessType = [System.Security.AccessControl.AccessControlType]::Allow
        $Rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Identity, $Rights, $AccessType

        $Acl = Get-Acl $Path
        $Acl.SetAccessRuleProtection($true, $false)
        $Acl.SetAccessRule($Rule)
        Set-Acl -Path $Path -AclObject $Acl
    }
    catch {
        Write-Warning "Could not lock down config file permissions automatically."
        Write-Warning "Please make sure only your Windows user can read $Path."
    }
}

Write-Host "MiMoClaude installer"
Write-Host

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Error "Claude Code was not found. Please install Claude Code first, then run this installer again."
    exit 1
}

Write-Host "Choose your MiMo API type:"
Write-Host "  1. Token Plan"
Write-Host "  2. API Pay-as-you-go"
$MimoApiTypeChoice = Read-Host "Selection [1/2]"

switch ($MimoApiTypeChoice) {
    "" {
        $MimoApiType = "token-plan"
        $MimoBaseUrl = $TokenPlanBaseUrl
    }
    "1" {
        $MimoApiType = "token-plan"
        $MimoBaseUrl = $TokenPlanBaseUrl
    }
    "2" {
        $MimoApiType = "pay-as-you-go"
        Write-Host
        Write-Host "Paste your MiMo Anthropic-compatible API base URL."
        Write-Host "Example format: https://example.com/anthropic"
        $MimoBaseUrl = Read-Host "Base URL"

        if ([string]::IsNullOrWhiteSpace($MimoBaseUrl)) {
            Write-Error "Base URL cannot be empty for API Pay-as-you-go."
            exit 1
        }
    }
    default {
        Write-Error "Please choose 1 for Token Plan or 2 for API Pay-as-you-go."
        exit 1
    }
}

Write-Host
Write-Host "Paste your MiMo API key."
if ($MimoApiType -eq "token-plan") {
    Write-Host "Token Plan keys usually start with tp-."
}
else {
    Write-Host "API Pay-as-you-go keys may use a different prefix."
}
$MimoApiKey = Read-PlainTextSecret "API key"

if ([string]::IsNullOrWhiteSpace($MimoApiKey)) {
    Write-Error "API key cannot be empty."
    exit 1
}

if (($MimoApiType -eq "token-plan") -and (-not $MimoApiKey.StartsWith("tp-"))) {
    Write-Warning "This Token Plan API key does not start with tp-."
    $ContinueInstall = Read-Host "Continue anyway? [y/N]"

    if ($ContinueInstall -notin @("y", "Y", "yes", "YES")) {
        Write-Host "Install cancelled."
        exit 1
    }
}

New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null

$Config = [ordered]@{
    MIMO_API_TYPE = $MimoApiType
    MIMO_BASE_URL = $MimoBaseUrl
    MIMO_API_KEY = $MimoApiKey
}

$Config | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
Protect-ConfigFile -Path $ConfigFile

New-Item -ItemType Directory -Path $BinDir -Force | Out-Null

@'
$ErrorActionPreference = "Stop"

$HomeDir = [Environment]::GetFolderPath("UserProfile")
$ConfigFile = Join-Path (Join-Path $HomeDir ".mimoclaude") "config"

if (-not (Test-Path $ConfigFile)) {
    Write-Error "MiMoClaude config not found at $ConfigFile. Run install.ps1 again to create it."
    exit 1
}

$Config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($Config.MIMO_API_KEY)) {
    Write-Error "MIMO_API_KEY is missing from $ConfigFile"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Config.MIMO_BASE_URL)) {
    Write-Error "MIMO_BASE_URL is missing from $ConfigFile"
    exit 1
}

$env:ANTHROPIC_BASE_URL = $Config.MIMO_BASE_URL
$env:ANTHROPIC_AUTH_TOKEN = $Config.MIMO_API_KEY
$env:ANTHROPIC_MODEL = "mimo-v2.5-pro"
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = "mimo-v2.5"
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = "mimo-v2.5-pro"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "mimo-v2.5"

& claude @args
exit $LASTEXITCODE
'@ | Set-Content -Path $CommandPs1 -Encoding UTF8

@"
@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\bin\mimoclaude.ps1" %*
"@ | Set-Content -Path $CommandCmd -Encoding ASCII

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ([string]::IsNullOrEmpty($UserPath)) {
    $UserPath = ""
}

$PathItems = $UserPath -split ";" | Where-Object { $_ -ne "" }
$BinDirAlreadyInPath = $false

foreach ($Item in $PathItems) {
    if ($Item.TrimEnd("\") -ieq $BinDir.TrimEnd("\")) {
        $BinDirAlreadyInPath = $true
    }
}

if (-not $BinDirAlreadyInPath) {
    $NewUserPath = if ($UserPath) { "$UserPath;$BinDir" } else { $BinDir }
    [Environment]::SetEnvironmentVariable("Path", $NewUserPath, "User")
    $env:Path = "$env:Path;$BinDir"
    $PathNote = "Added $BinDir to your user PATH."
}
else {
    $PathNote = "$BinDir is already in your user PATH."
}

Write-Host
Write-Host "MiMoClaude installed successfully."
Write-Host
Write-Host "Created:"
Write-Host "  $CommandCmd"
Write-Host "  $CommandPs1"
Write-Host "  $ConfigFile"
Write-Host
Write-Host "Configured API type: $MimoApiType"
Write-Host "Configured base URL: $MimoBaseUrl"
Write-Host
Write-Host $PathNote
Write-Host
Write-Host "Next steps:"
Write-Host "  1. Restart your terminal."
Write-Host "  2. Start Claude Code through your selected MiMo API with: mimoclaude"
Write-Host
Write-Host "Your normal claude command was not changed."
