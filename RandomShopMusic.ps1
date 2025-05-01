Set-StrictMode -Version Latest

function Write-Message($message, $color = "White") {
    $colors = @{
        "Green" = [System.ConsoleColor]::Green
        "Red" = [System.ConsoleColor]::Red
        "Cyan" = [System.ConsoleColor]::Cyan
        "White" = [System.ConsoleColor]::White
    }

    $oldColor = [System.Console]::ForegroundColor
    [System.Console]::ForegroundColor = $colors[$color]
    Write-Host $message
    [System.Console]::ForegroundColor = $oldColor
}

function Replace-JsonFieldValue {
    param (
        [string]$FilePath,
        [string]$FieldName,
        [string]$NewValue
    )

    if (-not (Test-Path $FilePath)) {
        Write-Message "$FilePath not found." "Red"
        return
    }

    $content = Get-Content $FilePath -Raw
    $pattern = '"{0}"\s*:\s*"[^"]*"' -f [regex]::Escape($FieldName)
    $replacement = '"{0}": "{1}"' -f $FieldName, $NewValue

    if ($content -match $pattern) {
        $content = [regex]::Replace($content, $pattern, $replacement)
        $trimmedContent = $content.TrimEnd()
        Set-Content -Path $FilePath -Value $trimmedContent -Encoding UTF8
        Write-Message "Updated field '$FieldName' in $(Split-Path $FilePath -Leaf)" "Cyan"
    } else {
        Write-Message "Field '$FieldName' not found in $(Split-Path $FilePath -Leaf)" "Red"
    }
}

$templateDir = "Template"
$pluginDir = Join-Path $templateDir "plugins"
$defaultPackName = "SOUND_PACK_NAME"

$packFolder = Get-ChildItem -Path $pluginDir -Directory | Select-Object -First 1
if (-not $packFolder) { Write-Message "No pack found!" "Red"; Pause; Exit }

$packName = $packFolder.Name
$oldFolder = $packFolder.FullName
$soundsDir = Join-Path $oldFolder "sounds"
$readmeFile = Join-Path $templateDir "README.md"

if (-not (Test-Path $soundsDir)) { Write-Message "Sounds folder missing." "Red" ; Pause; Exit }
$audioFiles = Get-ChildItem $soundsDir -Include *.mp3, *.ogg, *.wav -File -Recurse
if (-not $audioFiles) { 
    Write-Message "No audio files found." "Red"
    Add-Type -AssemblyName "System.Windows.Forms"
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Audio Files (*.mp3;*.ogg;*.wav)|*.mp3;*.ogg;*.wav"
    $dialog.Title = "Select Audio Files"
    $dialog.Multiselect = $true

    $dialogResult = $dialog.ShowDialog()
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($file in $dialog.FileNames) {
            $dest = Join-Path $soundsDir (Split-Path $file -Leaf)
            Copy-Item $file -Destination $dest
            Write-Message "$(Split-Path $file -Leaf) added." "Cyan"
        }
        $audioFiles = Get-ChildItem $soundsDir -Include *.mp3, *.ogg, *.wav -File -Recurse
    } else {
        Write-Message "No files selected. Exiting." "Red"
        Pause; Exit
    }
}

function Replace-InFile($filePath, $oldText, $newText) {
    (Get-Content $filePath -Raw) -replace [regex]::Escape($oldText), $newText | Set-Content $filePath -Encoding UTF8
}

function Update-ReadmeTrackList($readmePath, $audioFiles) {
    if (-not (Test-Path $readmePath)) { Write-Message "README.md missing." "Red" ; return }
    $content = Get-Content $readmePath -Raw -ErrorAction Stop
    $content = $content -replace "(?s)Track list.*", ""
    $trackList = "`nTrack list" + ($audioFiles | ForEach-Object { "`n- $($_.BaseName)" }) -join ''
    ($content.TrimEnd() + "`n`n" + $trackList) | Set-Content $readmePath -Encoding UTF8
}

function Validate-Version($version) {
    return $version -match '^\d+\.\d+\.\d+$'
}

function Compare-Versions($currentVersion, $newVersion) {
    $currentParts = $currentVersion.Split('.') | ForEach-Object { [int]$_ }
    $newParts = $newVersion.Split('.') | ForEach-Object { [int]$_ }
    for ($i = 0; $i -lt [Math]::Min($currentParts.Count, $newParts.Count); $i++) {
        if ($newParts[$i] -gt $currentParts[$i]) { return $true }
        if ($newParts[$i] -lt $currentParts[$i]) { return $false }
    }
    return $newParts.Count -gt $currentParts.Count
}

Write-Host "Options:"
Write-Host "[1] Create a new sound pack"
if ($packName -ne $defaultPackName) {
    Write-Host "[2] Update existing sound pack"
}

$choice = Read-Host "Enter your choice"

if ($choice -eq "2" -and $packName -eq $defaultPackName) {
    Write-Message "Cannot update SOUND_PACK_NAME. Create a new pack first." "Red"
    Pause; Exit
}

switch ($choice) {
'1' {
    $displayName = Read-Host "Enter sound pack name"
    $newPackName = ($displayName.Trim()) -replace '\s', '_'
    $newFolder = Join-Path $pluginDir $newPackName

    if (Test-Path $newFolder) {
        Write-Message "A pack named '$newPackName' already exists." "Red"
        Pause; Exit
    }

    $oldPackName = $packName
    Rename-Item $oldFolder -NewName $newPackName
    $oldFolder = $newFolder
    $packName = $newPackName

    $manifestPath = Join-Path $templateDir "manifest.json"
    $soundPackPath = Join-Path $oldFolder "sound_pack.json"

    if (Test-Path $manifestPath) {
        Replace-InFile $manifestPath $defaultPackName $newPackName
        Replace-InFile $manifestPath $oldPackName $newPackName
        Replace-JsonFieldValue -FilePath $manifestPath -FieldName "name" -NewValue $newPackName
    }

    if (Test-Path $soundPackPath) {
        Replace-InFile $soundPackPath $defaultPackName $newPackName
        Replace-InFile $soundPackPath $oldPackName $newPackName
        Replace-JsonFieldValue -FilePath $soundPackPath -FieldName "name" -NewValue $newPackName
    }

    if (Test-Path $readmeFile) {
        $readme = Get-Content $readmeFile
        if ($readme[0] -like "##*") { $readme[0] = "## $($displayName.Trim())" }
        $readme | Set-Content $readmeFile -Encoding UTF8
    }

    if (Test-Path $manifestPath) {
        (Get-Content $manifestPath -Raw) -replace '"version_number"\s*:\s*"[^"]+"', '"version_number": "1.0.0"' |
        Set-Content $manifestPath -Encoding UTF8
        Write-Message "Version reset to 1.0.0" "Cyan"
    }
}
'2' {
    Write-Message "Updating pack: $packName" "White"
    $manifestPath = Join-Path $templateDir "manifest.json"
    if (Test-Path $manifestPath) {
        $manifestContent = Get-Content $manifestPath -Raw
        if ($manifestContent -match '"version_number"\s*:\s*"([^"]+)"') {
            $currentVersion = $matches[1]
            Write-Host "Current version: $currentVersion"

            $parts = $currentVersion.Split(".")
            if ($parts.Count -eq 3) {
                $parts[2] = [int]$parts[2] + 1
                $suggestedVersion = "$($parts[0]).$($parts[1]).$($parts[2])"
            } else {
                $suggestedVersion = "1.0.1"
            }

            Write-Host "Suggested version: $suggestedVersion"
            $confirm = Read-Host "Update to suggested version? (Y/N)"
            if ($confirm -match "^[Yy]$") {
                $newVersion = $suggestedVersion
            } else {
                $newVersion = Read-Host "Enter new version number (format: X.Y.Z)"
                if (-not (Validate-Version $newVersion)) {
                    Write-Message "Invalid version format." "Red"
                    Pause; Exit
                }
                if (-not (Compare-Versions $currentVersion, $newVersion)) {
                    Write-Message "New version must be higher." "Red"
                    Pause; Exit
                }
            }

            $manifestContent -replace '"version_number"\s*:\s*"[^"]+"', "`"version_number`": `"$newVersion`"" |
            Set-Content $manifestPath -Encoding UTF8
            Write-Message "Version updated to $newVersion" "Cyan"
        }
    }
}
default {
    Write-Message "Invalid choice." "Red"
    Pause; Exit
}
}

Update-ReadmeTrackList -readmePath $readmeFile -audioFiles $audioFiles

$replacersDir = Join-Path $oldFolder "replacers"
$replacerJsonPath = Join-Path $replacersDir "replacer.json"
if (-not (Test-Path $replacersDir)) { New-Item -ItemType Directory -Path $replacersDir | Out-Null }

$updateReplacer = "Y"
if (Test-Path $replacerJsonPath) {
    $updateReplacer = Read-Host "replacer.json exists. Update it? (Y/N)"
}
if ($updateReplacer -match "^[Yy]$") {
    $soundsList = $audioFiles | ForEach-Object {
        "        {`n          `"sound`": `"$($_.Name)`",`n          `"weight`": 1`n        }"
    }
    $jsonContent = @"
{
  "replacements": [
    {
      "matches": "Module - Shop - N - Generic:Audio Loop Distance:shop music",
      "sounds": [
$(($soundsList -join ",`r`n"))
      ]
    }
  ]
}
"@
    $jsonContent | Set-Content $replacerJsonPath -Encoding UTF8
    Write-Message "replacer.json updated." "Cyan"
}

# --- Ask user if they want to zip the soundpack ---
$zipChoice = Read-Host "Would you like to create a zip of the sound pack? (Y/N)"
if ($zipChoice -match "^[Yy]$") {
    $soundPackDir = Join-Path (Get-Location) "soundpack"
    if (-not (Test-Path $soundPackDir)) {
        New-Item -ItemType Directory -Path $soundPackDir | Out-Null
    }

    $manifestContent = Get-Content (Join-Path $templateDir "manifest.json") -Raw
    $version = if ($manifestContent -match '"version_number"\s*:\s*"([^"]+)"') { $matches[1] } else { "1.0.0" }
    $zipNameSafe = ($packName -replace '[\\/:*?"<>|]', '_') + "-" + $version + ".zip"
    $zipFilePath = Join-Path $soundPackDir $zipNameSafe
    Compress-Archive -Path (Join-Path $templateDir "*") -DestinationPath $zipFilePath -Force

    Write-Message "Zipped pack created: $zipNameSafe" "Cyan"
} else {
    Write-Message "Skipping zip creation." "Cyan"
}

Write-Message "All done!" "Green"
Pause
