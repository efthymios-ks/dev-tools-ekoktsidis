param (
    [string]$RootFolder = "."
)

Import-Module './ef-common.psm1' -Force

function Select-Migration {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Migrations
    )

    Write-Host ""
    Write-Host "Select migration to update to (leave empty for latest):"

    do {
        $selection = Read-Host "Enter number (or empty)"
        if ([string]::IsNullOrWhiteSpace($selection)) {
            return $null
        }
        $valid = $selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $Migrations.Count
        if (-not $valid) {
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
        }
    } while (-not $valid)

    return $Migrations[[int]$selection - 1]
}

function Invoke-RemoveMigrationsAfter {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Migrations,

        [Parameter(Mandatory = $true)]
        [string]$TargetMigrationName,

        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    # Sort migrations ascending by DatePrefix
    $sortedMigrations = $Migrations | Sort-Object DatePrefix

    # Find index of target migration by RawName
    $targetIndex = -1
    for ($i = 0; $i -lt $sortedMigrations.Count; $i++) {
        if ($sortedMigrations[$i].RawName -ieq $TargetMigrationName) {
            $targetIndex = $i
            break
        }
    }

    if ($targetIndex -lt 0) {
        Write-Host "Target migration '$TargetMigrationName' not found." -ForegroundColor Red
        return
    }

    # Get migrations newer than target migration (to remove)
    if ($targetIndex -lt $sortedMigrations.Count - 1) {
        $toRemove = $sortedMigrations[($targetIndex + 1)..($sortedMigrations.Count - 1)]
    }
    else {
        $toRemove = @()
    }

    # Remove migrations starting from newest to oldest
    foreach ($migration in $toRemove | Sort-Object DatePrefix -Descending) {
        Write-Host "Removing migration $($migration.Name)..."
        $command = "dotnet ef migrations remove --project `"$ProjectPath`""
        Invoke-Expression $command
    }
}

function Invoke-UpdateDatabase {
    param(
        [string]$ProjectPath,
        [string]$MigrationName = ""
    )

    $command = "dotnet ef database update --project `"$ProjectPath`""
    if (-not [string]::IsNullOrEmpty($MigrationName)) {
        $command += " $MigrationName"
    }

    Write-Host ""
    Write-Host "Executing: $command" -ForegroundColor Yellow
    Invoke-Expression $command
}

# Select migrations folder
$migrationsFolder = Read-EfMigrationsFolder -RootFolder $RootFolder

# Get .csproj path
$projectFolder = Get-CsProjPath -StartFolder $migrationsFolder

# Get migrations
$migrations = Get-EfMigrations -ProjectFolder $projectFolder
Show-EfMigrations -Migrations $migrations -ShowNumbering

# Select target migration
$selectedMigration = Select-Migration -Migrations $migrations

if ($null -eq $selectedMigration) {
    # Just update to latest
    Invoke-UpdateDatabase -ProjectPath $projectFolder
    EXIT 0
}

# Update database to the selected migration first
Invoke-UpdateDatabase -ProjectPath $projectFolder -MigrationName $selectedMigration.RawName
# Then remove migrations newer than the selected migration
Invoke-RemoveMigrationsAfter -Migrations $migrations -TargetMigrationName $selectedMigration.RawName -ProjectPath $projectFolder
