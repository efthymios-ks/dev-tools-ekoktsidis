function Read-EfMigrationsFolder {
    param (
        [Parameter(Mandatory = $true)]
        [string]$RootFolder
    )

    $migrationFolders = Get-ChildItem -Path $RootFolder -Directory -Recurse |
    Where-Object { $_.Name -ieq "Migrations" }
    if ($migrationFolders.Count -eq 0) {
        Write-Host "No migrations folder found." -ForegroundColor Red
        EXIT 1
    }

    Write-Host "Select migrations folder:"
    for ($i = 0; $i -lt $migrationFolders.Count; $i++) {
        $fullPath = $migrationFolders[$i].FullName
        Write-Host -NoNewline "["
        Write-Host -NoNewline ($i + 1) -ForegroundColor Cyan
        Write-Host -NoNewline "] "
        Write-Host $fullPath
    }

    do {
        $selectedIndex = Read-Host "Pick (1 to $($migrationFolders.Count))"
        $isValid = $selectedIndex -match '^\d+$' -and [int]$selectedIndex -ge 1 -and [int]$selectedIndex -le $migrationFolders.Count
        if (-not $isValid) {
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
        }
    } while (-not $isValid)

    Write-Host "";
    return $migrationFolders[[int]$selectedIndex - 1].FullName
}

function Get-EfMigrations {
    param (
        [string]$ProjectFolder
    )

    Write-Host 'Gathering migrations...'
    $migrationsOutput = dotnet ef migrations list --project $ProjectFolder

    $migrations = @()
    foreach ($line in $migrationsOutput) {
        if ($line -match '^\d{14}_.+') {
            $rawName = $line.Trim()
            $isPending = $rawName -match '\(.*\)$'
            $cleanName = $rawName -replace '\s*\(.*\)$', ''
            $datePrefix = $cleanName.Substring(0, 14)

            $nameWithPossibleParens = $cleanName.Substring(15)
            $name = $nameWithPossibleParens -replace '\s*\(.*\)$', ''

            $fullPath = Get-ChildItem -Path $ProjectFolder -Filter "$cleanName.cs" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName

            $migrations += [PSCustomObject]@{
                RawName    = $rawName
                FullName   = $fullPath
                DatePrefix = $datePrefix
                Name       = $name
                IsPending  = $isPending
            }
        }
    }

    return $migrations
}

function Show-EfMigrations {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Migrations,

        [switch]$ShowNumbering
    )

    Write-Host "Existing migrations:"
    if ($Migrations.Count -eq 0) {
        Write-Host "None" -ForegroundColor Yellow
        EXIT 0;
    }

    for ($i = 0; $i -lt $Migrations.Count; $i++) {
        $migration = $Migrations[$i]
        if ($ShowNumbering) {
            Write-Host -NoNewline "["
            Write-Host -NoNewline ($i + 1) -ForegroundColor Cyan
            Write-Host -NoNewline "] "
        }

        Write-Host -NoNewline $migration.DatePrefix
        Write-Host -NoNewline "_"
        Write-Host -NoNewline $migration.Name -ForegroundColor Cyan

        if ($migration.IsPending) {
            Write-Host " (Pending)" -ForegroundColor Yellow
        }
        else {
            Write-Host ""
        }
    }
}

function Get-CsProjPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$StartFolder
    )

    $currentDirectory = Get-Item $StartFolder
    do {
        $csproj = Get-ChildItem -Path $currentDirectory.FullName -Filter *.csproj -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
        if ($csproj) {
            return $csproj.FullName
        }

        $sln = Get-ChildItem -Path $currentDirectory.FullName -Filter *.sln -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
        if ($sln) {
            Write-Host "Stopped search due to .sln file found at $($currentDirectory.FullName)" -ForegroundColor Red
            EXIT 1
        }

        $currentDirectory = $currentDirectory.Parent
    } while ($null -ne $currentDirectory)

    EXIT 1
}

Export-ModuleMember -Function Read-EfMigrationsFolder, Get-EfMigrations, Show-EfMigrations, Get-CsProjPath