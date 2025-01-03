# PowerShell script to install nightly build

# Get repository information from git
function Get-RepoInfo {
    $remoteUrl = git config --get remote.origin.url
    if ($remoteUrl -match "github\.com[:/]([^/]+)/([^/.]+)(\.git)?$") {
        return @{
            Owner = $matches[1]
            Repo = $matches[2]
            FullName = "$($matches[1])/$($matches[2])"
        }
    }
    return $null
}

# Try to get repo info from git, then fall back to environment variables
$repoInfo = Get-RepoInfo
$GITHUB_OWNER = if ($repoInfo) { $repoInfo.Owner } else { $env:GITHUB_REPOSITORY_OWNER }
$GITHUB_REPO = if ($repoInfo) { $repoInfo.Repo } else { $env:GITHUB_EVENT_REPOSITORY_NAME }
$GITHUB_REPOSITORY = if ($repoInfo) { $repoInfo.FullName } else { "$GITHUB_OWNER/$GITHUB_REPO" }

if (-not $GITHUB_REPOSITORY) {
    Write-Error "Could not determine GitHub repository information"
    exit 1
}

# Ensure we're running with elevated privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as Administrator"
    exit 1
}

# Define installation paths
$installDir = "$env:ProgramFiles\$GITHUB_REPO"
$binPath = "$installDir\$GITHUB_REPO.exe"

# Create installation directory if it doesn't exist
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

# Get the latest nightly release info
$apiUrl = "https://api.github.com/repos/$GITHUB_REPOSITORY/releases"
try {
    $releases = Invoke-RestMethod -Uri $apiUrl
} catch {
    Write-Error "Failed to fetch releases: $_"
    exit 1
}

# Find the latest nightly release
$latestNightly = $releases | Where-Object { $_.tag_name -like "nightly-*" } | Select-Object -First 1
if (-not $latestNightly) {
    Write-Error "No nightly release found"
    exit 1
}

# Construct the download URL
$downloadUrl = "https://github.com/$GITHUB_REPOSITORY/releases/download/$($latestNightly.tag_name)/$GITHUB_REPO-windows-x64-nightly-$($latestNightly.tag_name.Substring(8)).exe"

Write-Host "Downloading $GITHUB_REPO nightly build $($latestNightly.tag_name)..."
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $binPath
} catch {
    Write-Error "Failed to download $GITHUB_REPO: $_"
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

Write-Host "$GITHUB_REPO nightly build has been installed to $binPath"
Write-Host "Run '$GITHUB_REPO --help' to get started"
