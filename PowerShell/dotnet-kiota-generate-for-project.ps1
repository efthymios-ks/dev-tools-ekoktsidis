function Write-Info {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'HH:mm:ss') [INFO] $Message"
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "$(Get-Date -Format 'HH:mm:ss') [ERROR] $Message" -ForegroundColor Red
}

function Get-SafeTitle {
    param([string]$Title)

    $safe = ($Title -replace '[^a-zA-Z0-9_]', '')
    if ($safe -match '^\d') {
        $safe = "_$safe"
    }

    return $safe
}

function Get-CurrentPath {
    return (Get-Location).Path.TrimEnd('\')
}

function Get-CsProjFiles {
    param([string]$Path)

    $files = Get-ChildItem -Path $Path -Recurse -Filter *.csproj
    if ($files.Count -eq 0) {
        Write-ErrorMessage "No csproj files found under $Path"
        exit 1
    }

    return $files
}

function Get-WebSdkProjects {
    param([System.IO.FileInfo[]]$CsProjFiles)

    $webProjects = @()
    foreach ($file in $CsProjFiles) {
        try {
            $xmlContent = Get-Content $file.FullName -Raw
            [xml]$xml = $xmlContent
            if ($xml.Project.Sdk -eq "Microsoft.NET.Sdk.Web") {
                $webProjects += $file
            }
        }
        catch {
            Write-ErrorMessage "Failed to parse $($file.FullName)"
            exit 1
        }
    }

    if ($webProjects.Count -eq 0) {
        Write-ErrorMessage "No Web SDK csproj files found"
        exit 1
    }

    return $webProjects
}

function Select-Project {
    param(
        [System.IO.FileInfo[]]$Projects,
        [string]$CurrentPath
    )

    Write-Info "Select a Web SDK project:"
    for ($i = 0; $i -lt $Projects.Count; $i++) {
        $relativePath = $Projects[$i].FullName.Substring($CurrentPath.Length + 1)
        Write-Host -NoNewline ("[" + ($i + 1) + "]") -ForegroundColor Cyan
        Write-Host " $relativePath"
    }

    do {
        $selection = Read-Host "Select project by number"
    } while (-not ($selection -match '^\d+$') -or [int]$selection -lt 1 -or [int]$selection -gt $Projects.Count)

    $selected = $Projects[[int]$selection - 1].FullName
    Write-Info "Selected project: $selected"
    return $selected
}

function Get-ProjectTargetFramework {
    param(
        [string]$CsProjPath,
        [string]$ScriptPath
    )

    $directoryBuildPropsKey = "Directory.Build.props"
    $csProjDir = Split-Path $CsProjPath -Parent
    $scriptDir = Split-Path $ScriptPath -Parent
    $pathsToCheck = @($CsProjPath)
    $currentDir = $csProjDir
    while ($true) {
        $propsPath = Join-Path -Path $currentDir -ChildPath $directoryBuildPropsKey
        $pathsToCheck += $propsPath

        if ($currentDir -eq $scriptDir) {
            break
        }

        $parentDir = Split-Path $currentDir -Parent
        if ([string]::IsNullOrEmpty($parentDir) -or $parentDir -eq $currentDir) {
            break
        }

        $currentDir = $parentDir
    }

    foreach ($path in $pathsToCheck) {
        if (-not (Test-Path $path)) {
            continue
        }

        try {
            $content = Get-Content $path -Raw
            [xml]$xml = $content
            $node = $xml.SelectSingleNode("//Project/PropertyGroup/TargetFramework | //Project/PropertyGroup/TargetFrameworks")

            if (-not $node -or $node.InnerText.Trim() -eq '') {
                continue
            }

            return $node.InnerText.Trim()
        }
        catch {
            # Ignore parse errors and continue
        }
    }

    Write-ErrorMessage "TargetFramework not found in csproj or Directory.Build.props"
    exit 1
}

function Get-ProjectNamespace {
    param([string]$CsProjPath)

    $csprojContent = Get-Content $CsProjPath -Raw
    [xml]$xml = $csprojContent
    $rootNsNode = $xml.SelectSingleNode("//Project/PropertyGroup/RootNamespace")

    if ($rootNsNode -and $rootNsNode.InnerText -ne '') {
        return $rootNsNode.InnerText
    }
    else {
        return [System.IO.Path]::GetFileNameWithoutExtension($CsProjPath)
    }
}

function Get-SwaggerJsonPath {
    param([string]$ProjectPath)

    $swaggerPath = Join-Path -Path (Split-Path $ProjectPath) -ChildPath "swagger.json"
    if (-Not (Test-Path $swaggerPath)) {
        Write-ErrorMessage "swagger.json not found next to project"
        exit 1
    }

    Write-Info "Found swagger.json at: $swaggerPath"
    return $swaggerPath
}

function Reset-ApiClientProject {
    param(
        [string]$ApiProjectPath,
        [string]$TargetFramework
    )

    $apiFolder = Split-Path -Path $ApiProjectPath -Parent
    $apiParentFolder = Split-Path -Path $apiFolder -Parent
    $apiName = [System.IO.Path]::GetFileNameWithoutExtension($ApiProjectPath)
    $apiFolderName = Split-Path -Leaf $apiFolder
    $apiClientProjectFolder = Join-Path -Path $apiParentFolder -ChildPath ($apiFolderName + ".Client")

    if (Test-Path $apiClientProjectFolder) {
        Write-Info "Deleting existing client folder: $apiClientProjectFolder"
        Remove-Item -Path $apiClientProjectFolder -Recurse -Force
    }

    Write-Info "Creating client project folder: $apiClientProjectFolder"
    New-Item -ItemType Directory -Path $apiClientProjectFolder | Out-Null

    $apiClientCsprojPath = Join-Path -Path $apiClientProjectFolder -ChildPath ($apiName + ".Client.csproj")
    $apiClientCsprojContent = @"
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup Label="Package">
        <RootNamespace>$Namespace.Client</RootNamespace>
        <AssemblyName>$Namespace.Client</AssemblyName>
        <TargetFramework>$TargetFramework</TargetFramework>
        <RunAnalyzers>false</RunAnalyzers>
        <ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally>
    </PropertyGroup>

    <ItemGroup Label="Exclude from code coverage">
        <AssemblyAttribute Include="System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute" />
    </ItemGroup>

</Project>
"@
    $apiClientCsprojContent | Set-Content -Path $apiClientCsprojPath -Encoding UTF8
    Write-Info "Created client project file at: $apiClientCsprojPath"

    return $apiClientProjectFolder, $apiClientCsprojPath
}

function Test-KiotaInstalled {
    Write-Info "Checking if Kiota is installed globally..."

    try {
        & kiota --version *> $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Kiota is already installed globally"
            return
        }
    }
    catch {
        # ignore
    }

    Write-Info "Kiota not found. Installing globally..."
    & dotnet tool install --global Microsoft.OpenApi.Kiota
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Failed to install Kiota globally"
        exit 1
    }

    Write-Info "Kiota installed successfully"
}

function New-KiotaApiClient {
    param(
        [string]$SwaggerJsonPath,
        [string]$ApiClientFolder,
        [string]$ApiNamespace
    )

    # Use the parameter directly
    $apiClientNamespace = "$ApiNamespace.Client"

    # Output folder inside client project
    $apiClientOutputDir = Join-Path -Path $ApiClientFolder -ChildPath "Generated"

    Write-Info "Generating Kiota API client at $apiClientOutputDir with namespace $apiClientNamespace..."

    if (-Not (Test-Path $apiClientOutputDir)) {
        New-Item -ItemType Directory -Path $apiClientOutputDir | Out-Null
    }

    $env:KIOTA_TUTORIAL_ENABLED = "false"
    $kiotaArgs = @(
        "generate",
        "--openapi", $SwaggerJsonPath,
        "--output", $apiClientOutputDir,
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

    Write-Info "Kiota API client generated at: $apiClientOutputDir"
}

function Install-KiotaDependencies {
    param(
        [string]$SwaggerJsonPath,
        [string]$ClientCsprojPath
    )

    Write-Info "Fetching required Kiota dependencies..."

    $kiotaInfoArgs = @(
        "-d", $SwaggerJsonPath,
        "-l", "CSharp"
    )

    # Capture output
    $output = & kiota info @kiotaInfoArgs 2>$null | Out-String
    if (-not $output) {
        Write-ErrorMessage "Failed to get Kiota info output"
        exit 1
    }

    # Parse table lines (skip header)
    $lines = $output -split "`n" | ForEach-Object { $_.Trim() }
    $tableStart = $lines | Select-String -Pattern '^Package Name\s+Version' | ForEach-Object { $_.LineNumber }
    if (-not $tableStart) {
        Write-Info "No additional packages required"
        return
    }

    $packageLines = $lines[$tableStart..($lines.Length - 1)] | Where-Object { $_ -match '^\w' }

    foreach ($line in $packageLines) {
        $parts = $line -split '\s+'
        if ($parts.Length -ge 2) {
            $packageName = $parts[0]
            $packageVersion = $parts[1]
            Write-Info "Installing $packageName $packageVersion..."
            & dotnet add "`"$ClientCsprojPath`"" package $packageName --version $packageVersion *> $null
            if ($LASTEXITCODE -ne 0) {
                Write-ErrorMessage "Failed to install package $packageName"
                exit 1
            }
        }
    }

    Write-Info "All required Kiota dependencies installed silently"
}

function New-ReadMeMd {
    param(
        [string]$ApiClientFolder,
        [string]$ApiNamespace
    )

    $safeNamespace = Get-SafeTitle -Title $ApiNamespace
    $content = @"

# $safeNamespace Client

## DI Registration

``````CSharp
// Client interface
public interface I${safeNamespace}Client
{
    /*
        Override with methods and use DTOs directly from inside the generated code
    */
}
``````

``````CSharp
// Client implementation wrapper
public sealed class ${safeNamespace}ClientWrapper(IRequestAdapter requestAdapter)
    : ${ApiNamespace}.Client.ApiClient(requestAdapter), I${safeNamespace}Client
{
}
``````

``````CSharp
// DI
public static IServiceCollection Add${safeNamespace}Client(
    this IServiceCollection services,
    IConfiguration configuration
)
{
    ArgumentNullException.ThrowIfNull(services);
    ArgumentNullException.ThrowIfNull(configuration);

    services.TryAddSingleton<IAuthenticationProvider>(new AnonymousAuthenticationProvider());

    const string httpClientName = "${safeNamespace}Client";
    services.AddHttpClient(httpClientName, httpClient =>
    {
        var section = configuration.GetSection(httpClientName);
        var baseAddress = section.GetValue<string>("Domain")!.TrimEnd('/') + '/';
        var timeout = section.GetValue<TimeSpan?>("Timeout") ?? TimeSpan.FromSeconds(60);

        httpClient.BaseAddress = new(baseAddress);
        httpClient.Timeout = timeout;
    });

    services.TryAddTransient<I${safeNamespace}Client>(serviceProvider =>
    {
        var factory = serviceProvider.GetRequiredService<IHttpClientFactory>();
        var httpClient = factory.CreateClient(httpClientName);

        var authProvider = serviceProvider.GetRequiredService<IAuthenticationProvider>();
        var adapter = new HttpClientRequestAdapter(authProvider, httpClient: httpClient);
        return new ${safeNamespace}ClientWrapper(adapter);
    });

    return services;
}
``````

``````JSON
// appsettings.json
{
  "${safeNamespace}Client": {
    "Domain": "https://api.example.com/v1.0/",
    "Timeout": "00:01:00"
  }
}
``````
"@

    $readMePath = Join-Path -Path $ApiClientFolder -ChildPath "README.md"
    $content | Set-Content -Path $readMePath -Encoding UTF8
    Write-Info "Generated README.md at: $readMePath"
}

# Main
$currentPath = Get-CurrentPath
$csprojFiles = Get-CsProjFiles -Path $currentPath
$webProjects = Get-WebSdkProjects -CsProjFiles $csprojFiles
$selectedProject = Select-Project -Projects $webProjects -CurrentPath $currentPath
$targetFramework = Get-ProjectTargetFramework -CsProjPath $selectedProject -ScriptPath $currentPath
$namespace = Get-ProjectNamespace -CsProjPath $selectedProject

$swaggerPath = Get-SwaggerJsonPath -ProjectPath $selectedProject

$apiClientFolder, $apiClientCsprojPath = Reset-ApiClientProject -ApiProjectPath $selectedProject -TargetFramework $targetFramework

Test-KiotaInstalled
New-KiotaApiClient -SwaggerJsonPath $swaggerPath -ApiClientFolder $apiClientFolder -ApiNamespace $namespace -PathsToExclude $excludePaths
Install-KiotaDependencies -SwaggerJsonPath $swaggerPath -ClientCsprojPath $apiClientCsprojPath

New-ReadMeMd -ApiClientFolder $apiClientFolder -ApiNamespace $namespace