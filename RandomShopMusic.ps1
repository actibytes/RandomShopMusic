<#
.SYNOPSIS
    Generates a replacer JSON file using template files for the LoaforcsSoundAPI mod to play custom sounds.

.DESCRIPTION
    This script:
    - Checks for audio files (.mp3, .ogg, .wav) inside the Template\plugins\SOUND_PACK_NAME\sounds folder.
    - Asks the user for a new sound pack name (uses underscores for files but keeps spaces for display).
    - Renames the SOUND_PACK_NAME folder.
    - Replaces "SOUND_PACK_NAME" in manifest.json, README.md, and sound_pack.json.
    - Updates Track list for the README.md.
    - Generates a replacer.json listing all sounds with weight 1.
    - Allows updating replacer.json later when new sounds are added.

.AUTHOR
    actibytes - Discord

.REVISION
    2025-04-29
#>

Set-StrictMode -Version Latest

# Paths
$templateDir = "Template"
$pluginDir = Join-Path $templateDir "plugins"
$defaultPackName = "SOUND_PACK_NAME"

# Find pack folder
$packFolder = Get-ChildItem -Path $pluginDir -Directory | Select-Object -First 1
if (-not $packFolder) { Write-Host "No pack found!" ; Pause; Exit }

$packName = $packFolder.Name
$oldFolder = $packFolder.FullName
$soundsDir = Join-Path $oldFolder "sounds"
$readmeFile = Join-Path $templateDir "README.md"

# Validate sounds
if (-not (Test-Path $soundsDir)) { Write-Host "Sounds folder missing." ; Pause; Exit }
$audioFiles = Get-ChildItem $soundsDir -Include *.mp3, *.ogg, *.wav -File -Recurse
if (-not $audioFiles) { Write-Host "No audio files found." ; Pause; Exit }

# Functions
function Replace-InFile($filePath, $oldText, $newText) {
    (Get-Content $filePath -Raw) -replace [regex]::Escape($oldText), $newText | Set-Content $filePath -Encoding UTF8
}

function Update-ReadmeTrackList($readmePath, $audioFiles) {
    if (-not (Test-Path $readmePath)) { Write-Host "README.md missing." ; return }
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

# Main Menu
Write-Host "Options:"
Write-Host "[1] Create a new sound pack"
if ($packName -ne $defaultPackName) { Write-Host "[2] Update existing sound pack" }

$choice = Read-Host "Enter your choice"

if ($choice -eq "2" -and $packName -eq $defaultPackName) {
    Write-Host "Cannot update SOUND_PACK_NAME. Create a new pack first."
    Pause; Exit
}

switch ($choice) {
'1' {
    # --- Create new sound pack ---
    $displayName = Read-Host "Enter the new sound pack display name"
    $newPackName = $displayName -replace '\s', '_'
    $newFolder = Join-Path $pluginDir $newPackName

    # Rename folder
    Rename-Item $oldFolder -NewName $newPackName
    $oldFolder = $newFolder

    # Replace names in files
    Replace-InFile (Join-Path $templateDir "manifest.json") $packName $newPackName
    Replace-InFile (Join-Path $oldFolder "sound_pack.json") $packName $newPackName

    # Update README header
    if (Test-Path $readmeFile) {
        $readme = Get-Content $readmeFile
        if ($readme[0] -like "##*") { $readme[0] = "## $displayName" }
        $readme | Set-Content $readmeFile -Encoding UTF8
    }

    # Reset version if not default SOUND_PACK_NAME
    if ($packName -ne $defaultPackName) {
        if (Test-Path (Join-Path $templateDir "manifest.json")) {
            (Get-Content (Join-Path $templateDir "manifest.json") -Raw) -replace '"version_number"\s*:\s*"[^"]+"', '"version_number": "1.0.0"' |
            Set-Content (Join-Path $templateDir "manifest.json") -Encoding UTF8
            Write-Host "Version reset to 1.0.0"
        }
    }
}
'2' {
    # --- Update existing pack ---
    Write-Host "Updating pack: $packName"

    if (Test-Path (Join-Path $templateDir "manifest.json")) {
        $manifestContent = Get-Content (Join-Path $templateDir "manifest.json") -Raw
        if ($manifestContent -match '"version_number"\s*:\s*"([^"]+)"') {
            $currentVersion = $matches[1]
            Write-Host "Current version: $currentVersion"

            # Auto-suggest next patch version
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
                    Write-Host "Invalid version format. Must be like 1.2.3"
                    Pause; Exit
                }
                if (-not (Compare-Versions $currentVersion $newVersion)) {
                    Write-Host "New version must be higher than current version ($currentVersion)."
                    Pause; Exit
                }
            }

            # Write updated version
            $manifestContent -replace '"version_number"\s*:\s*"[^"]+"', "`"version_number`": `"$newVersion`"" |
            Set-Content (Join-Path $templateDir "manifest.json") -Encoding UTF8
            Write-Host "Version updated to $newVersion"
        }
    }
}
default {
    Write-Host "Invalid choice." ; Pause; Exit
}
}

# --- Always update Tracklist ---
Update-ReadmeTrackList -readmePath $readmeFile -audioFiles $audioFiles

# --- Create or Update replacer.json ---
$replacersDir = Join-Path $oldFolder "replacers"
$replacerJsonPath = Join-Path $replacersDir "replacer.json"

if (-not (Test-Path $replacersDir)) { New-Item -ItemType Directory -Path $replacersDir | Out-Null }

if (-not (Test-Path $replacerJsonPath)) {
    Write-Host "Creating replacer.json..."
    $createOrUpdate = "Y"
} else {
    $createOrUpdate = Read-Host "replacer.json exists. Update it? (Y/N)"
}

if ($createOrUpdate -match "^[Yy]$") {
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

    $jsonContent | Set-Content -Path $replacerJsonPath -Encoding UTF8
    Write-Host "replacer.json updated."
}

Write-Host "All done!"
Pause
