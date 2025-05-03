# Menu Script Entry Point
function Show-Menu {
    do {
        Clear-Host
        Write-Host "=== Sound Pack Manager ==="
        Write-Host "1. Create a new sound pack"
        Write-Host "2. Update an existing sound pack"
        Write-Host "0. Exit"
        $choice = Read-Host "Select an option"

        switch ($choice) {
            "1" { Create-NewSoundPack }
            "2" { Update-ExistingSoundPack }
            "0" { return }
            default { Write-Host "Invalid selection. Try again." }
        }

        Pause
    } while ($true)
}

# Helper Functions
function Create-JsonContent($filePath, $jsonContent) {
    $jsonContent = $jsonContent.Trim()
    [System.IO.File]::WriteAllText($filePath, $jsonContent, [System.Text.Encoding]::UTF8)
    Write-Host "Created $filePath"
}

function Copy-AudioFiles($audioFiles, $destinationFolder) {
    foreach ($file in $audioFiles) {
        Copy-Item -Path $file -Destination $destinationFolder -Force
    }
    Write-Host "[OK] Copied $($audioFiles.Count) audio file(s) to '$destinationFolder'"
}

function Update-Readme($readmePath, $packDisplayName, $audioFiles) {
    $readmeContent = Get-Content $readmePath -Raw
    $lines = $readmeContent -split "`n"
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^##\s*') {
            $lines[$i] = "## $packDisplayName"
            break
        }
    }
    $readmeContent = ($lines -join "`n") -replace '(\n\nTrack list(.|\n)*)$', ''

    $trackList = "`n`nTrack list"
    if ($audioFiles.Count -gt 0) {
        foreach ($file in $audioFiles | Sort-Object Name) {
            $trackList += "`n- " + $file.BaseName
        }
    } else {
        $trackList += "`n`n(No audio files found in sounds folder)"
    }

    $readmeContent += $trackList
    [System.IO.File]::WriteAllText($readmePath, $readmeContent, [System.Text.Encoding]::UTF8)
    Write-Host "Updated README.md with sound pack name and track list"
}

function Create-ReplacersJson($replacersJsonPath, $audioFiles) {
    $soundObjects = $audioFiles | ForEach-Object {
@"
        {
          "sound": "$($_.Name)",
          "weight": 1
        }
"@
    }

    $replacersJsonContent = @"
{
  "replacements": [
    {
      "matches": "Module - Shop - N - Generic:Audio Loop Distance:shop music",
      "sounds": [
$(($soundObjects -join ",`r`n"))
      ]
    }
  ]
}
"@

    Create-JsonContent -filePath $replacersJsonPath -jsonContent $replacersJsonContent
}

function Sanitize-SoundPackName($inputName) {
    $words = ($inputName.Trim() -replace '_+', ' ') -split '\s+' | ForEach-Object {
        $w = ($_ -replace '[^a-zA-Z0-9]', '')
        if ($w.Length -gt 0) {
            $w.Substring(0, 1).ToUpper() + $w.Substring(1).ToLower()
        }
    }
    return $words -join ''
}

function Show-AudioFileDialog {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select audio files"
    $dialog.Filter = "Audio Files (*.mp3;*.ogg;*.wav)|*.mp3;*.ogg;*.wav"
    $dialog.Multiselect = $true
    return $dialog
}

function Ensure-FolderExists($path) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory | Out-Null
    }
}

function Ask-ToZipFolder($templateFolderPath, $zipBaseName, $version) {
    $zipPrompt = Read-Host "Do you want to zip the entire Template folder as '$zipBaseName-$version.zip'? (Y/N)"
    if ($zipPrompt -match '^(?i)y(?:es)?$') {
        $outputFolder = ".\SoundPacks"
        if (-not (Test-Path $outputFolder)) {
            New-Item -Path $outputFolder -ItemType Directory | Out-Null
        }

        $zipPath = Join-Path $outputFolder "$zipBaseName-$version.zip"
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

        $itemsToZip = Get-ChildItem -Path $templateFolderPath
        Compress-Archive -Path $itemsToZip.FullName -DestinationPath $zipPath

        Write-Host "[OK] Created zip archive: $zipPath"
    }
}

# Main Option: Create a new sound pack
function Create-NewSoundPack {
    $templateRoot = ".\Template"
    $pluginFolderPath = Join-Path $templateRoot "plugins"
    $existingPlugin = Get-ChildItem -Path $pluginFolderPath -Directory | Select-Object -First 1

    if (-not $existingPlugin) {
        Write-Host "[Error] No folder found in 'Template\plugins'." -ForegroundColor Red
        return
    }

    $inputName = Read-Host "Enter the new sound pack name"
    $cleanName = Sanitize-SoundPackName $inputName

    if (-not $cleanName) {
        Write-Host "[Error] Invalid name. Must contain at least one alphanumeric word." -ForegroundColor Red
        return
    }

    $displayName = $cleanName -replace '_', ' '
    $renamedPluginFolder = Join-Path $pluginFolderPath $cleanName
    $originalPluginPath = Join-Path $pluginFolderPath $existingPlugin.Name
    $soundPackJsonPath = Join-Path $renamedPluginFolder "sound_pack.json"
    $soundsFolder = Join-Path $renamedPluginFolder "sounds"
    $replacersJsonPath = Join-Path $renamedPluginFolder "replacers\replacers.json"
    $readmePath = Join-Path $templateRoot "README.md"
    $manifestPath = Join-Path $templateRoot "manifest.json"

    $dialog = Show-AudioFileDialog
    if ($dialog.ShowDialog() -eq "OK" -and $dialog.FileNames.Count -gt 0) {

        $manifestContent = @"
{
  "name": "$cleanName",
  "version_number": "1.0.0",
  "website_url": "",
  "description": "Play random songs while at the shop",
  "dependencies": [
    "BepInEx-BepInExPack-5.4.2100",
    "loaforc-loaforcsSoundAPI-2.0.6"
  ]
}
"@
        Create-JsonContent -filePath $manifestPath -jsonContent $manifestContent

        if (-not (Test-Path $renamedPluginFolder)) {
            Rename-Item -Path $originalPluginPath -NewName $cleanName
            Write-Host "Renamed folder to '$cleanName'"
        } else {
            Write-Host "[Warning] Folder '$cleanName' already exists. Skipping rename."
        }

        $soundPackContent = @"
{
  "name": "$cleanName"
}
"@
        Create-JsonContent -filePath $soundPackJsonPath -jsonContent $soundPackContent

        Ensure-FolderExists $soundsFolder
        Copy-AudioFiles $dialog.FileNames $soundsFolder

        $audioFiles = Get-ChildItem -Path $soundsFolder -File | Where-Object { $_.Extension -in ".mp3", ".ogg", ".wav" }
        Update-Readme $readmePath $displayName $audioFiles
        Create-ReplacersJson $replacersJsonPath $audioFiles

        Write-Host "[OK] Sound pack '$cleanName' created."

        $version = "1.0.0"
        Ask-ToZipFolder -templateFolderPath ".\Template" -zipBaseName $cleanName -version $version

    } else {
        Write-Host "[Warning] No audio files selected. Skipping pack creation." -ForegroundColor Yellow
    }
}

# Main Option: Update an existing sound pack
function Update-ExistingSoundPack {
    $pluginRoot = ".\Template\plugins"
    $existingPlugin = Get-ChildItem -Path $pluginRoot -Directory | Select-Object -First 1

    if (-not $existingPlugin) {
        Write-Host "[Error] No folder found in '$pluginRoot'." -ForegroundColor Red
        return
    }

    if ($existingPlugin.Name -eq "SOUND_PACK_NAME") {
        Write-Host "[Error] The current folder is still named 'SOUND_PACK_NAME'. You must create a new sound pack first." -ForegroundColor Red
        return
    }

    $packName = $existingPlugin.Name
    $packPath = $existingPlugin.FullName
    Write-Host "Found sound pack folder: $packName"

    $manifestPath = ".\Template\manifest.json"
    $readmePath = ".\Template\README.md"
    $soundsFolder = Join-Path $packPath "sounds"
    $replacersJsonPath = Join-Path $packPath "replacers\replacers.json"

    $dialog = Show-AudioFileDialog
    if ($dialog.ShowDialog() -eq "OK" -and $dialog.FileNames.Count -gt 0) {
        Ensure-FolderExists $soundsFolder
        Copy-AudioFiles $dialog.FileNames $soundsFolder
    }

    $audioFiles = Get-ChildItem -Path $soundsFolder -File | Where-Object { $_.Extension -in ".mp3", ".ogg", ".wav" }

    $displayName = $packName -replace '_', ' '
    Update-Readme $readmePath $displayName $audioFiles
    Create-ReplacersJson $replacersJsonPath $audioFiles

    $updateVersion = Read-Host "Do you want to update the version number in manifest.json? (Y/N)"
    if ($updateVersion -eq 'Y') {
        if (Test-Path $manifestPath) {
            $manifest = Get-Content $manifestPath | ConvertFrom-Json
            $currentVersion = [version]$manifest.version_number
            $newVersion = [version]::new($currentVersion.Major, $currentVersion.Minor, $currentVersion.Build + 1)
            $formattedManifest = @"
{
  "name": "$($manifest.name)",
  "version_number": "$newVersion",
  "website_url": "$($manifest.website_url)",
  "description": "$($manifest.description)",
  "dependencies": [
    "BepInEx-BepInExPack-5.4.2100",
    "loaforc-loaforcsSoundAPI-2.0.6"
  ]
}
"@
            Create-JsonContent -filePath $manifestPath -jsonContent $formattedManifest
            Write-Host "Updated manifest.json to version $newVersion"
        } else {
            Write-Host "[Warning] manifest.json not found." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Version number remains the same."
    }

    Write-Host "[OK] Sound pack '$packName' updated."

    if (Test-Path $manifestPath) {
        $manifest = Get-Content $manifestPath | ConvertFrom-Json
        $version = $manifest.version_number
    } else {
        $version = "unknown"
    }
    Ask-ToZipFolder -templateFolderPath ".\Template" -zipBaseName $packName -version $version

}

# Start the menu
Show-Menu
