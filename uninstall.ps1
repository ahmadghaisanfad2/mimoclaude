$ErrorActionPreference = "Stop"

$HomeDir = [Environment]::GetFolderPath("UserProfile")
$ConfigDir = Join-Path $HomeDir ".mimoclaude"
$CommandPs1 = Join-Path (Join-Path $HomeDir "bin") "mimoclaude.ps1"
$CommandCmd = Join-Path (Join-Path $HomeDir "bin") "mimoclaude.cmd"

Write-Host "MiMoClaude uninstaller"
Write-Host

if (Test-Path $CommandCmd) {
    Remove-Item -Path $CommandCmd -Force
    Write-Host "Removed $CommandCmd"
}
else {
    Write-Host "No command found at $CommandCmd"
}

if (Test-Path $CommandPs1) {
    Remove-Item -Path $CommandPs1 -Force
    Write-Host "Removed $CommandPs1"
}
else {
    Write-Host "No PowerShell helper found at $CommandPs1"
}

if (Test-Path $ConfigDir) {
    Remove-Item -Path $ConfigDir -Recurse -Force
    Write-Host "Removed $ConfigDir"
}
else {
    Write-Host "No config directory found at $ConfigDir"
}

Write-Host
Write-Host "MiMoClaude was uninstalled."
Write-Host
Write-Host "Note: PATH entries were not removed automatically."
Write-Host "If the installer added your user bin folder to PATH, you can remove it manually from:"
Write-Host "  Windows Settings > System > About > Advanced system settings > Environment Variables"
