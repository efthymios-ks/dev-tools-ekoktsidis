# Utility functions
function Write-Info {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'HH:mm:ss') [INFO] $Message"
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'HH:mm:ss') [ERROR] $Message" -ForegroundColor Red
}

function Get-CurrentPath {
    return (Get-Location).Path.TrimEnd('\')
}

function Get-SafeTitle {
    param([string]$Title)
    $safe = ($Title -replace '[^a-zA-Z0-9_]', '')
    if ($safe -match '^\d') { $safe = "_$safe" }
    return $safe
}

function Test-KiotaInstalled {
    Write-Info "Checking if Kiota is installed globally..."
    & kiota --version *> $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Info "Kiota not found. Installing globally..."
        & dotnet tool install --global Microsoft.OpenApi.Kiota
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMessage "Failed to install Kiota globally"
            exit 1
        }
        Write-Info "Kiota installed successfully"
    }
    else {
        Write-Info "Kiota is already installed globally"
    }
}

function Get-SwaggerFiles {
    param([string]$SourceFolder)
    if (-not (Test-Path $SourceFolder)) {
        Write-ErrorMessage "Sources folder not found: $SourceFolder"
        exit 1
    }
    $files = Get-ChildItem -Path $SourceFolder -Filter "*swagger*.json" -Recurse
    if ($files.Count -eq 0) {
        Write-ErrorMessage "No swagger JSON files found in $SourceFolder"
        exit 1
    }
    return $files
}

function New-KiotaApiClient {
    param(
        [string]$SwaggerJsonPath,
        [string]$GeneratedRootFolder,
        [string]$ApiNamespace
    )

    $apiClientNamespace = "$ApiNamespace.Client"
    $clientFolder = Join-Path -Path $GeneratedRootFolder -ChildPath $ApiNamespace

    Write-Info "Generating Kiota API client at $clientFolder with namespace $apiClientNamespace..."

    if (-Not (Test-Path $clientFolder)) {
        New-Item -ItemType Directory -Path $clientFolder | Out-Null
    }

    $env:KIOTA_TUTORIAL_ENABLED = "false"
    $kiotaArgs = @(
        "generate",
        "--openapi", $SwaggerJsonPath,
        "--output", $clientFolder,
        "--language", "CSharp",
        "--namespace-name", $apiClientNamespace,
        "--additional-data", "false",
        "--log-level", "warning",
        "--clean-output"
    )

    & kiota @kiotaArgs

    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Kiota API client generation failed"
        exit 1
    }

    Write-Info "Kiota API client generated at: $clientFolder"
}

function Install-KiotaDependencies {
    param(
        [string]$SwaggerJsonPath,
        [string]$ProjectPath
    )

    Write-Info "Fetching required Kiota dependencies..."

    $output = & kiota info -d $SwaggerJsonPath -l CSharp 2>$null | Out-String
    if (-not $output) {
        Write-Info "No additional packages required"
        return
    }

    $lines = $output -split "`n" | ForEach-Object { $_.Trim() }
    $tableStart = $lines | Select-String -Pattern '^Package Name\s+Version' | ForEach-Object { $_.LineNumber }
    if (-not $tableStart) { return }

    $packageLines = $lines[$tableStart..($lines.Length - 1)] | Where-Object { $_ -match '^\w' }

    foreach ($line in $packageLines) {
        $parts = $line -split '\s+'
        if ($parts.Length -ge 2) {
            $packageName = $parts[0]
            $packageVersion = $parts[1]
            Write-Info "Installing $packageName $packageVersion into $ProjectPath..."
            & dotnet add "`"$ProjectPath`"" package $packageName --version $packageVersion *> $null
        }
    }

    Write-Info "All required Kiota dependencies installed in $ProjectPath"
}

function Get-MainCsproj {
    param([string]$CurrentPath)

    $csprojFiles = Get-ChildItem -Path $CurrentPath -Filter "*.csproj"
    if ($csprojFiles.Count -eq 0) {
        Write-ErrorMessage "No .csproj file found in $CurrentPath"
        exit 1
    }

    if ($csprojFiles.Count -gt 1) {
        Write-ErrorMessage "Multiple .csproj files found in $CurrentPath. Please keep only one."
        exit 1
    }

    return $csprojFiles[0].FullName
}

# Main execution
$currentPath = Get-CurrentPath
$sourcesFolder = Join-Path $currentPath "Swaggers"
$generatedRoot = Join-Path $currentPath "Generated"
$mainCsproj = Get-MainCsproj -CurrentPath $currentPath

if (-not (Test-Path $generatedRoot)) {
    New-Item -ItemType Directory -Path $generatedRoot | Out-Null
}

Test-KiotaInstalled
$swaggerFiles = Get-SwaggerFiles -SourceFolder $sourcesFolder

foreach ($file in $swaggerFiles) {
    $json = Get-Content $file.FullName -Raw | ConvertFrom-Json
    $title = $json.info.title
    $safeTitle = Get-SafeTitle -Title $title

    # Generate under Generated/<ClientName>
    New-KiotaApiClient -SwaggerJsonPath $file.FullName -GeneratedRootFolder $generatedRoot -ApiNamespace $safeTitle
    Install-KiotaDependencies -SwaggerJsonPath $file.FullName -ProjectPath $mainCsproj
}

Write-Info "All swagger files processed."
