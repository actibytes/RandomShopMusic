# SoundPackManager

**SoundPackManager** is a PowerShell-based utility that helps automate the creation of **Shop music packs** for **R.E.P.O.**, a modding system powered by the `loaforcsSoundAPI`. It uses a standardized template structure to streamline the process of customizing shop music in your game.

## Features

- 🛠️ Automatically generates replacer files based on your audio tracks  
- 🎵 Supports batch creation of shop music packs  
- 📁 Follows loaforcsSoundAPI’s expected directory and file structure  
- ⚡ Reduces manual setup and speeds up your audio modding workflow

## Use Case

Ideal for music pack creators who want to easily add their own tracks and upload them to **Thunderstore**.

## Getting Started

Follow these simple steps to create or update a custom sound pack with **SoundPackManager**.

### 📥 1. Download and Extract

1. **[Download the latest version here](https://github.com/actibytes/RandomShopMusic/releases/latest/download/SoundPackManager.zip)**  

2. Extract the downloaded ZIP file. You’ll get a folder named **SoundPackManager**.

3. Open that folder to begin.

---

## 🎵 Creating a Sound Pack

 **Change the Icon** *(Optional)*  
   - Use a 256x256 PNG image.  
   - You can resize and crop here: [https://imageresizer.com](https://imageresizer.com)
   - Overwrite the icon.png in `Template\icon.png`

 **Run the Script**  
   - Right-click on `SoundPackManager.ps1`
   - Choose **Run with PowerShell**
     - Type `1` and press Enter to create a new sound pack.
     - When prompted, type your sound pack name and press Enter.
     - Select your Audio Files using the File dialog

---

## 🔁 Updating a Sound Pack

**Modify Audio Files**  
   - Go to:  
     `Template\plugins\<YOUR_SOUND_PACK_NAME>\sounds\`  
   - Remove audio files as needed.

**Run the Script**  
   - Right-click `RandomShopMusic.ps1` > **Run with PowerShell**
     - Type `2` and press Enter to update the pack.
     - Select your Audio Files using the File dialog
     - Follow the prompts to confirm or Deny.

---
 ## If you skip zip creation, manually create the ZIP File
   - Open the **Template** folder.  
   - Select the five items inside it (not the folder itself).  
   - Right-click > **Send to** > **Compressed (zipped) folder**
