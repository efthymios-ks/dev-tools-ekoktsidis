param (
    [string]$RootFolder = "."
)

Import-Module './ef-common.psm1' -Force

function Confirm-AddMigration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MigrationName
    )

    Write-Host ""
    Write-Host -NoNewline "Add migration "
    Write-Host -NoNewline "$MigrationName" -ForegroundColor Green
    Write-Host "? (y/n)"
    $confirm = Read-Host
    return $confirm -ieq 'y'
}

function Invoke-AddMigration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MigrationName,

        [Parameter(Mandatory = $true)]
        [string]$MigrationsFolder,

        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    $command = "dotnet ef migrations add $MigrationName --output-dir `"$MigrationsFolder`" --project `"$ProjectPath`""
    Write-Host ""
    Write-Host "Executing: $command" -ForegroundColor Yellow
    Invoke-Expression $command
}

# Select migrations folder
$migrationsFolder = Read-EfMigrationsFolder -RootFolder $RootFolder

# Enter new migration name
$migrationName = Read-Host "Enter migration name"
Write-Host ""

# Get .csproj path
$projectFolder = Get-CsProjPath -StartFolder $migrationsFolder

# Get migrations
$migrations = Get-EfMigrations -ProjectFolder $projectFolder
Show-EfMigrations -Migrations $migrations

# Confirm operation
if (-not (Confirm-AddMigration -MigrationName $migrationName)) {
    Write-Host "Cancelled." -ForegroundColor Yellow
    EXIT 0
}

# Execute
Invoke-AddMigration -MigrationName $migrationName -MigrationsFolder $migrationsFolder -ProjectPath $projectFolder
