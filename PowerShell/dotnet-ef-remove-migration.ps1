param (
    [string]$RootFolder = "."
)

Import-Module './ef-common.psm1' -Force

function Confirm-RemoveMigration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MigrationName
    )

    Write-Host ""
    Write-Host -NoNewline "Remove migration "
    Write-Host -NoNewline "$MigrationName" -ForegroundColor Green
    Write-Host "? (y/n)"
    $confirm = Read-Host
    return $confirm -ieq 'y'
}

function Invoke-RemoveMigration {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    $command = "dotnet ef migrations remove --project `"$ProjectPath`""
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
Show-EfMigrations -Migrations $migrations

# Pick last migration by DatePrefix for removal
$migrationToRemove = $migrations | Sort-Object DatePrefix | Select-Object -Last 1

# Confirm operation
if (-not (Confirm-RemoveMigration -MigrationName $migrationToRemove.Name)) {
    Write-Host "Cancelled." -ForegroundColor Yellow
    EXIT 0
}

# Execute
Invoke-RemoveMigration -ProjectPath $projectFolder
