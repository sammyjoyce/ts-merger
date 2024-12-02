# PowerShell script to install fuze

# Ensure we're running with elevated privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as Administrator"
    exit 1
}

# Define installation paths
$installDir = "$env:ProgramFiles\fuze"
$binPath = "$installDir\fuze.exe"

# Create installation directory if it doesn't exist
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

# Download URL for the latest release
$downloadUrl = "https://github.com/sammyjoyce/fuze/releases/latest/download/fuze-windows-x64.exe"

Write-Host "Downloading fuze..."
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $binPath
} catch {
    Write-Error "Failed to download fuze: $_"
    exit 1
}

# Add to PATH if not already present
$currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
if ($currentPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable(
        "Path",
        "$currentPath;$installDir",
        [EnvironmentVariableTarget]::Machine
    )
}

Write-Host "fuze has been installed to $binPath"
Write-Host "Run 'fuze --help' to get started"
