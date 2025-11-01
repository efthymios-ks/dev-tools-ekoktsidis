# Color scheme constants
$script:Colors = @{
    HeaderBorder = "Cyan"
    HeaderTitle = "Yellow"
    MenuNumber = "Green"
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
}

function Write-SectionHeader {
    param(
        [string]$title
    )
    
    Write-Host ""
    Write-Host "======================================" -ForegroundColor $script:Colors.HeaderBorder
    Write-Host "  $title" -ForegroundColor $script:Colors.HeaderTitle
    Write-Host "======================================" -ForegroundColor $script:Colors.HeaderBorder
}

function Write-SectionFooter {
    Write-Host "======================================" -ForegroundColor $script:Colors.HeaderBorder
    Write-Host ""
}

function Invoke-EfCommand {
    param(
        [string]$command
    )
    
    # Build the full command with prefix output
    $efCommand = "dotnet ef $command --prefix-output 2>&1"
    
    # Execute command
    $output = Invoke-Expression $efCommand | Out-String
    
    # Parse output
    $result = @{
        Success = $true
        ErrorMessages = @()
        DataLines = @()
        RawOutput = $output
    }
    
    # Extract error and data lines
    $lines = $output -split "`n"
    foreach ($line in $lines) {
        if ($line -match "^error:\s+(.+)$") {
            $result.ErrorMessages += $matches[1].Trim()
            $result.Success = $false
        }
        elseif ($line -match "^data:\s+(.+)$") {
            $result.DataLines += $matches[1].Trim()
        }
    }
    
    return $result
}

function Try-InstallDotNetEfTool {
    Write-SectionHeader "Check dotnet-ef tool"
    
    Write-Host "Checking if dotnet-ef tool is installed..."
    
    $efCheck = dotnet ef --version 2>&1 | Out-String
    
    if ($efCheck -match "Could not execute" -or $efCheck -notmatch "\d+\.\d+\.\d+") {
        Write-Host "Tool is not installed. Installing..."
        
        $installOutput = dotnet tool install --global dotnet-ef 2>&1 | Out-String
        
        if ($installOutput -notmatch "successfully installed") {
            Write-Host "ERROR: Failed to install tool" -ForegroundColor $script:Colors.Error
            Write-Host $installOutput
            exit 1
        }
        
        $efCheck = dotnet ef --version 2>&1 | Out-String
    }
    
    # Extract version from dotnet ef --version output
    if ($efCheck -match "(\d+\.\d+\.\d+)") {
        $version = $matches[1]
        Write-Host "Tool is installed ($version)"
    }
    
    Write-SectionFooter
}

function Get-ProjectFiles {
    $projects = Get-ChildItem -Path . -Filter "*.csproj" -Recurse | Select-Object -ExpandProperty FullName
    return $projects
}

function Get-ExecutableProjects {
    $projects = Get-ProjectFiles
    $executableProjects = @()
    
    foreach ($project in $projects) {
        $content = Get-Content $project -Raw
        
        if ($content -match '<Project Sdk="Microsoft\.NET\.Sdk\.Web">' -or $content -match '<OutputType>Exe</OutputType>') {
            $executableProjects += $project
        }
    }
    
    return $executableProjects
}

function Get-RelativePath {
    param(
        [string]$path
    )
    
    $scriptPath = $PSScriptRoot
    if ([string]::IsNullOrEmpty($scriptPath)) {
        $scriptPath = Get-Location
    }
    
    $fullPath = [System.IO.Path]::GetFullPath($path)
    $scriptFullPath = [System.IO.Path]::GetFullPath($scriptPath)
    
    if ($fullPath.StartsWith($scriptFullPath)) {
        $relativePath = $fullPath.Substring($scriptFullPath.Length).TrimStart('\', '/')
        return $relativePath
    }
    
    return $path
}

function Show-ProjectMenu {
    param(
        [string]$prompt,
        [array]$projects
    )
    
    Write-Host ""
    Write-Host $prompt
    for ($i = 0; $i -lt $projects.Count; $i++) {
        $projectName = Split-Path $projects[$i] -Leaf
        $projectDir = Split-Path (Split-Path $projects[$i] -Parent) -Leaf
        Write-Host "[" -NoNewline
        Write-Host ($i + 1) -ForegroundColor $script:Colors.MenuNumber -NoNewline
        Write-Host "] $projectDir\$projectName"
    }
    
    $selection = Read-Host "Enter selection (1-$($projects.Count))"
    $index = [int]$selection - 1
    
    if ($index -lt 0 -or $index -ge $projects.Count) {
        Write-Host "ERROR: Invalid selection" -ForegroundColor $script:Colors.Error
        exit 1
    }
    
    return $projects[$index]
}

function Try-Configure {
    Write-SectionHeader "Configure projects"
    
    $configPath = Join-Path $PSScriptRoot "dotnet-efman-config.json"
    
    # Try to load existing configuration
    if (Test-Path $configPath) {
        Write-Host "Loading configuration from dotnet-efman-config.json..."
        $config = Get-Content $configPath | ConvertFrom-Json
        
        # Validate configuration
        if (-not (Test-Path $config.StartupProject)) {
            Write-Host "ERROR: Startup project not found: $($config.StartupProject)" -ForegroundColor $script:Colors.Error
            Write-Host "Configuration is invalid. Please reconfigure"
            Remove-Item $configPath
            Write-SectionFooter
            return Try-Configure
        }
        
        if (-not (Test-Path $config.DataProject)) {
            Write-Host "ERROR: Data project not found: $($config.DataProject)" -ForegroundColor $script:Colors.Error
            Write-Host "Configuration is invalid. Please reconfigure"
            Remove-Item $configPath
            Write-SectionFooter
            return Try-Configure
        }
        
        Write-Host "Configuration loaded successfully"
        Write-Host "Startup Project: $(Get-RelativePath $config.StartupProject)"
        Write-Host "Data Project: $(Get-RelativePath $config.DataProject)"
        Write-SectionFooter
        return $config
    }
    
    # Create new configuration
    Write-Host "No configuration found. Creating new configuration..."
    
    $executableProjects = Get-ExecutableProjects
    $allProjects = Get-ProjectFiles
    
    if ($executableProjects.Count -eq 0) {
        Write-Host "ERROR: No executable projects found" -ForegroundColor $script:Colors.Error
        exit 1
    }
    
    if ($allProjects.Count -eq 0) {
        Write-Host "ERROR: No .csproj files found in the current directory" -ForegroundColor $script:Colors.Error
        exit 1
    }
    
    $startupProject = Show-ProjectMenu -prompt "Select the startup/executable project (e.g., API):" -projects $executableProjects
    $dataProject = Show-ProjectMenu -prompt "Select the data project (where DbContext and migrations are defined):" -projects $allProjects
    
    $config = @{
        StartupProject = $startupProject
        DataProject = $dataProject
    }
    
    $config | ConvertTo-Json | Set-Content $configPath
    
    Write-Host "Configuration saved to dotnet-efman-config.json"
    Write-Host "Startup Project: $(Get-RelativePath $config.StartupProject)"
    Write-Host "Data Project: $(Get-RelativePath $config.DataProject)"
    
    Write-SectionFooter
    return $config
}

function Ensure-EfCoreDesignPackage {
    param(
        [string]$projectPath
    )
    
    Write-SectionHeader "Check EF Core Design package"
    
    Write-Host "Checking if Microsoft.EntityFrameworkCore.Design is referenced in startup project..."
    
    $projectContent = Get-Content $projectPath -Raw
    $hasDesignPackage = $projectContent -match '<PackageReference\s+Include="Microsoft\.EntityFrameworkCore\.Design"'
    
    if (-not $hasDesignPackage) {
        Write-Host "Package is not installed. Installing..."
        
        $installOutput = dotnet add $projectPath package Microsoft.EntityFrameworkCore.Design 2>&1 | Out-String
        
        if ($installOutput -notmatch "PackageReference.*added to file") {
            Write-Host "ERROR: Failed to install package" -ForegroundColor $script:Colors.Error
            Write-Host $installOutput
            exit 1
        }
        
        $projectContent = Get-Content $projectPath -Raw
    }
    
    # Extract version from project file
    if ($projectContent -match '<PackageReference\s+Include="Microsoft\.EntityFrameworkCore\.Design"\s+Version="([^"]+)"') {
        $version = $matches[1]
        Write-Host "Package is installed ($version)"
    }
    
    Write-SectionFooter
}

function List-Migrations {
    param(
        [string]$startupProject,
        [string]$dataProject
    )
    
    Write-SectionHeader "List migrations"
    
    Write-Host "Listing migrations from data project..."
    
    $command = "migrations list --project `"$dataProject`" --startup-project `"$startupProject`""
    $result = Invoke-EfCommand -command $command
    
    if (-not $result.Success) {
        Write-Host "ERROR: Failed to list migrations" -ForegroundColor $script:Colors.Error
        foreach ($error in $result.ErrorMessages) {
            Write-Host $error -ForegroundColor $script:Colors.Error
        }
    }
    elseif ($result.DataLines.Count -eq 0 -or $result.RawOutput -match "No migrations were found") {
        Write-Host "No migrations found"
    }
    else {
        foreach ($migration in $result.DataLines) {
            Write-Host $migration
        }
    }
    
    Write-SectionFooter
}

function Add-Migration {
    param(
        [string]$startupProject,
        [string]$dataProject
    )
    
    Write-SectionHeader "Add migration"
    
    Write-Host "Enter migration name:"
    $migrationName = Read-Host "Name"
    
    if ([string]::IsNullOrWhiteSpace($migrationName)) {
        Write-Host "ERROR: Migration name cannot be empty" -ForegroundColor $script:Colors.Error
        Write-SectionFooter
        return
    }
    
    # Check if migrations already exist
    $listCommand = "migrations list --project `"$dataProject`" --startup-project `"$startupProject`""
    $listResult = Invoke-EfCommand -command $listCommand
    $migrationsExist = $listResult.DataLines.Count -gt 0
    
    $command = "migrations add `"$migrationName`" --project `"$dataProject`" --startup-project `"$startupProject`""
    
    if (-not $migrationsExist) {
        Write-Host "No existing migrations found"
        Write-Host "Enter migrations folder path (relative to data project, leave empty for /Migrations):"
        $folderPath = Read-Host "Folder path"
        
        $outputDir = if ([string]::IsNullOrWhiteSpace($folderPath)) { "Migrations" } else { $folderPath.TrimStart('/', '\') }
        
        Write-Host "Using migrations folder: /$outputDir"
        $command += " --output-dir `"$outputDir`""
    }
    
    Write-Host "Adding migration '$migrationName'..."
    
    $result = Invoke-EfCommand -command $command
    
    if (-not $result.Success) {
        Write-Host "ERROR: Failed to add migration" -ForegroundColor $script:Colors.Error
        foreach ($error in $result.ErrorMessages) {
            Write-Host $error -ForegroundColor $script:Colors.Error
        }
    }
    elseif ($result.RawOutput -match "Done") {
        Write-Host "Migration added successfully" -ForegroundColor $script:Colors.Success
    }
    
    Write-SectionFooter
}

function Update-Database {
    param(
        [string]$startupProject,
        [string]$dataProject
    )
    
    Write-SectionHeader "Update database"
    
    Write-Host "Listing available migrations..."
    
    $listCommand = "migrations list --project `"$dataProject`" --startup-project `"$startupProject`""
    $listResult = Invoke-EfCommand -command $listCommand
    
    if (-not $listResult.Success) {
        Write-Host "ERROR: Failed to list migrations" -ForegroundColor $script:Colors.Error
        foreach ($error in $listResult.ErrorMessages) {
            Write-Host $error -ForegroundColor $script:Colors.Error
        }
        Write-SectionFooter
        return
    }
    
    if ($listResult.DataLines.Count -eq 0) {
        Write-Host "No migrations found"
        Write-SectionFooter
        return
    }
    
    Write-Host ""
    Write-Host "Available migrations:"
    for ($i = 0; $i -lt $listResult.DataLines.Count; $i++) {
        Write-Host "[" -NoNewline
        Write-Host ($i + 1) -ForegroundColor $script:Colors.MenuNumber -NoNewline
        Write-Host "] $($listResult.DataLines[$i])"
    }
    
    Write-Host ""
    Write-Host "Enter migration number to update to (leave empty to update to latest):"
    $selection = Read-Host "Selection"
    
    $command = "database update --project `"$dataProject`" --startup-project `"$startupProject`""
    
    if (-not [string]::IsNullOrWhiteSpace($selection)) {
        $index = [int]$selection - 1
        
        if ($index -lt 0 -or $index -ge $listResult.DataLines.Count) {
            Write-Host "ERROR: Invalid selection" -ForegroundColor $script:Colors.Error
            Write-SectionFooter
            return
        }
        
        $targetMigration = $listResult.DataLines[$index] -replace "\s+\(Pending\)", "" -replace "\s+\(Applied\)", ""
        Write-Host "Updating database to migration: $targetMigration..."
        $command = "database update `"$targetMigration`" --project `"$dataProject`" --startup-project `"$startupProject`""
    } else {
        Write-Host "Updating database to latest migration..."
    }
    
    $result = Invoke-EfCommand -command $command
    
    if (-not $result.Success) {
        Write-Host "ERROR: Failed to update database" -ForegroundColor $script:Colors.Error
        foreach ($error in $result.ErrorMessages) {
            Write-Host $error -ForegroundColor $script:Colors.Error
        }
    }
    elseif ($result.RawOutput -match "Done" -or $result.RawOutput -match "Applying migration") {
        Write-Host "Database updated successfully" -ForegroundColor $script:Colors.Success
    }
    elseif ($result.RawOutput -match "No migrations were applied") {
        Write-Host "No migrations were applied. Database is already up to date"
    }
    else {
        foreach ($line in $result.DataLines) {
            Write-Host $line
        }
    }
    
    Write-SectionFooter
}

function Remove-Migration {
    param(
        [string]$startupProject,
        [string]$dataProject
    )
    
    Write-SectionHeader "Remove migration"
    
    Write-Host "Listing available migrations..."
    
    $listCommand = "migrations list --project `"$dataProject`" --startup-project `"$startupProject`""
    $listResult = Invoke-EfCommand -command $listCommand
    
    if (-not $listResult.Success) {
        Write-Host "ERROR: Failed to list migrations" -ForegroundColor $script:Colors.Error
        foreach ($error in $listResult.ErrorMessages) {
            Write-Host $error -ForegroundColor $script:Colors.Error
        }
        Write-SectionFooter
        return
    }
    
    if ($listResult.DataLines.Count -eq 0) {
        Write-Host "No migrations found"
        Write-SectionFooter
        return
    }
    
    Write-Host ""
    Write-Host "Current migrations:"
    foreach ($migration in $listResult.DataLines) {
        Write-Host $migration
    }
    
    Write-Host ""
    Write-Host "This will remove the last migration"
    Write-Host "Do you want to continue? (y/n):"
    $confirmation = Read-Host "Confirm"
    
    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
        Write-Host "Operation cancelled"
        Write-SectionFooter
        return
    }
    
    Write-Host "Removing last migration..."
    
    $command = "migrations remove --project `"$dataProject`" --startup-project `"$startupProject`""
    $result = Invoke-EfCommand -command $command
    
    if (-not $result.Success) {
        Write-Host "ERROR: Failed to remove migration" -ForegroundColor $script:Colors.Error
        foreach ($error in $result.ErrorMessages) {
            Write-Host $error -ForegroundColor $script:Colors.Error
        }
    }
    elseif ($result.RawOutput -match "Done" -or $result.RawOutput -match "Removing migration") {
        Write-Host "Migration removed successfully" -ForegroundColor $script:Colors.Success
    }
    else {
        foreach ($line in $result.DataLines) {
            Write-Host $line
        }
    }
    
    Write-SectionFooter
}

function Update-DotNetEfTool {
    Write-SectionHeader "Update dotnet-ef tool"
    
    Write-Host "Enter version to update to (leave empty for latest):"
    $version = Read-Host "Version"
    
    if ([string]::IsNullOrWhiteSpace($version)) {
        Write-Host "Updating dotnet-ef tool to latest version..."
        $updateOutput = dotnet tool update --global dotnet-ef 2>&1 | Out-String
    } else {
        Write-Host "Updating dotnet-ef tool to version $version..."
        
        # Check current version
        $efCheck = dotnet ef --version 2>&1 | Out-String
        $currentVersion = ""
        if ($efCheck -match "(\d+\.\d+\.\d+)") {
            $currentVersion = $matches[1]
        }
        
        # For specific version, uninstall first to allow downgrades
        if ($currentVersion) {
            Write-Host "Current version: $currentVersion"
            Write-Host "Uninstalling current version..."
            dotnet tool uninstall --global dotnet-ef | Out-Null
        }
        
        Write-Host "Installing version $version..."
        $updateOutput = dotnet tool install --global dotnet-ef --version $version 2>&1 | Out-String
    }
    
    if ($updateOutput -match "successfully updated" -or $updateOutput -match "successfully installed") {
        $efCheck = dotnet ef --version 2>&1 | Out-String
        if ($efCheck -match "(\d+\.\d+\.\d+)") {
            $currentVersion = $matches[1]
            Write-Host "Tool updated successfully ($currentVersion)" -ForegroundColor $script:Colors.Success
        }
    } elseif ($updateOutput -match "is up to date" -or $updateOutput -match "already installed") {
        $efCheck = dotnet ef --version 2>&1 | Out-String
        if ($efCheck -match "(\d+\.\d+\.\d+)") {
            $currentVersion = $matches[1]
            Write-Host "Tool is already at the latest version ($currentVersion)"
        }
    } else {
        Write-Host "ERROR: Failed to update tool" -ForegroundColor $script:Colors.Error
        Write-Host $updateOutput
    }
    
    Write-SectionFooter
}

function Reset-Config {
    Write-SectionHeader "Reset configuration"
    
    $configPath = Join-Path $PSScriptRoot "dotnet-efman-config.json"
    
    if (Test-Path $configPath) {
        Write-Host "Removing configuration file..."
        Remove-Item $configPath
        Write-Host "Configuration removed"
    } else {
        Write-Host "No configuration file found"
    }
    
    Write-SectionFooter
    
    Write-Host "Restarting script..."
    Write-Host ""
    
    & $PSCommandPath
    exit
}

function Show-MainMenu {
    param(
        [object]$config
    )
    
    Write-SectionHeader "EF Core Migration Manager"
    
    Write-Host "[" -NoNewline
    Write-Host "1" -ForegroundColor $script:Colors.MenuNumber -NoNewline
    Write-Host "] List migrations"
    
    Write-Host "[" -NoNewline
    Write-Host "2" -ForegroundColor $script:Colors.MenuNumber -NoNewline
    Write-Host "] Add migration"
    
    Write-Host "[" -NoNewline
    Write-Host "3" -ForegroundColor $script:Colors.MenuNumber -NoNewline
    Write-Host "] Update database"
    
    Write-Host "[" -NoNewline
    Write-Host "4" -ForegroundColor $script:Colors.MenuNumber -NoNewline
    Write-Host "] Remove migration"
    
    Write-Host ""
    
    Write-Host "[" -NoNewline
    Write-Host "8" -ForegroundColor $script:Colors.MenuNumber -NoNewline
    Write-Host "] Update dotnet-ef tool"
    
    Write-Host "[" -NoNewline
    Write-Host "9" -ForegroundColor $script:Colors.MenuNumber -NoNewline
    Write-Host "] Reset configuration"
    
    Write-Host "[" -NoNewline
    Write-Host "0" -ForegroundColor $script:Colors.MenuNumber -NoNewline
    Write-Host "] Exit"
    
    Write-Host ""
    
    $selection = Read-Host "Select an action"
    
    Write-SectionFooter
    
    switch ($selection) {
        "1" { List-Migrations -startupProject $config.StartupProject -dataProject $config.DataProject; Show-MainMenu -config $config }
        "2" { Add-Migration -startupProject $config.StartupProject -dataProject $config.DataProject; Show-MainMenu -config $config }
        "3" { Update-Database -startupProject $config.StartupProject -dataProject $config.DataProject; Show-MainMenu -config $config }
        "4" { Remove-Migration -startupProject $config.StartupProject -dataProject $config.DataProject; Show-MainMenu -config $config }
        "8" { Update-DotNetEfTool; Show-MainMenu -config $config }
        "9" { Reset-Config }
        "0" { Write-Host "Exiting..."; exit 0 }
        default { 
            Write-Host "ERROR: Invalid selection" -ForegroundColor $script:Colors.Error
            Show-MainMenu -config $config
        }
    }
}
 
Try-InstallDotNetEfTool
$config = Try-Configure
Ensure-EfCoreDesignPackage -projectPath $config.StartupProject

Show-MainMenu -config $config
