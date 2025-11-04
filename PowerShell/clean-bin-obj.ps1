$basePath = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "Searching for /bin and /obj folders under: $basePath`n"

$folders = Get-ChildItem -Path $basePath -Recurse -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ieq 'bin' -or $_.Name -ieq 'obj' } |
    Sort-Object FullName

if (-not $folders) {
    Write-Host "No bin/obj folders found."
    return
}

Write-Host "Found $($folders.Count) bin/obj folders.`nStarting cleanup...`n"

foreach ($folder in $folders) {
    $path = $folder.FullName
    try {
        Remove-Item -Recurse -Force -Path $path -ErrorAction Stop
        Write-Host "Deleted: $path"
    }
    catch {
        Write-Warning "Failed to delete: $path  -->  $($_.Exception.Message)"
    }
}

Write-Host "`nCleanup complete."
