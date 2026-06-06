# SonicDesk - README (Updated)

## 📋 Overview

**SonicDesk** is a user-friendly Windows application that helps you analyze audio compression quality and create M3U playlists with Linux-compatible formatting. No command line required — just point and click!

## ✨ Features

### 1. Audio Analyzer
- **Scan audio files** recursively through folders and subfolders (supports MP3, FLAC, WAV, OGG, etc.)
- **Extract metadata**: Bitrate, sample rate, channels, duration  
- **Quality assessment**: Automatically evaluates compression quality (Very High to Low)  
- **Export to CSV**: Save results as CSV files (single file or per folder)  
- **Real-time progress**: See analysis progress with visual feedback  
- **FFprobe integration**: Enhanced metadata extraction with configurable path
- **Settings persistence**: Remembers your last folders and preferences
- **Stop button**: Cancel long-running operations at any time

### 2. M3U Creator
- **Create playlists** from folders containing audio files  
- **Relative paths only** — makes playlists portable across systems  
- **Linux format option** — converts backslashes to forward slashes  
- **Extended M3U format** — includes duration metadata  
- **Recursive scanning** — include subfolders automatically  
- **Preview before saving** — see all tracks that will be added  
- **Stop button**: Cancel playlist creation at any time

### 3. Bitrate Reference Guide
- **Complete reference** for CBR and VBR bitrates  
- **Quality recommendations** for different use cases  
- **File size estimates** per minute of audio  

## 📥 Installation

### Prerequisites
- Windows 7, 8, 10, or 11  
- PowerShell 5.0 or later  
- Windows Media Player (usually pre-installed)
- **FFmpeg/FFprobe (Optional but Recommended)** - For enhanced metadata extraction

### Installing FFprobe (Recommended for Best Results)

FFprobe provides much more accurate and detailed audio metadata extraction. SonicDesk now includes a **Settings button** where you can configure the FFprobe path.

#### Option 1: System PATH Installation (Recommended)

1. Download FFmpeg from: https://ffmpeg.org/download.html
   - Click "Windows" icon
   - Download the latest "Windows builds" from gyan.dev
   - Recommended: https://www.gyan.dev/ffmpeg/builds/ (get "release essentials")

2. Extract the downloaded ZIP file to `C:\ffmpeg`

3. Add FFmpeg to your system PATH:
   - Open System Properties (Win + Pause/Break)
   - Click "Advanced system settings"
   - Click "Environment Variables"
   - Under "System variables", select "Path" and click "Edit"
   - Click "New" and add `C:\ffmpeg\bin`
   - Click OK on all dialogs

4. Restart PowerShell or your computer

5. In SonicDesk, set FFprobe path to `ffprobe` (default) or leave blank

#### Option 2: Direct Path Configuration in SonicDesk

1. Install FFmpeg to any location (e.g., `D:\tools\ffmpeg\bin\ffprobe.exe`)
2. Launch SonicDesk
3. Click the **Settings** button next to the Browse button
4. In the settings dialog, click "Browse" to locate `ffprobe.exe`
5. Click "Save" - settings are saved immediately

#### Option 3: Quick PATH Setup (PowerShell Admin)

Run this in an Administrator PowerShell console:
```powershell
# Download and extract FFmpeg to C:\ffmpeg
Invoke-WebRequest -Uri "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" -OutFile "$env:TEMP\ffmpeg.zip"
Expand-Archive -Path "$env:TEMP\ffmpeg.zip" -DestinationPath "C:\" -Force
Rename-Item "C:\ffmpeg-*" "C:\ffmpeg" -Force

# Add to PATH
$oldPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$newPath = "$oldPath;C:\ffmpeg\bin"
[Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")

Write-Host "FFmpeg installed! Please restart PowerShell." -ForegroundColor Green
```

### Verify FFprobe Installation

After installation, open a new PowerShell window and run:
```powershell
ffprobe -version
```

If you see version information, FFprobe is successfully installed!

### SonicDesk Setup
1. Download `SonicDesk.ps1` to your desired location  
2. The script will automatically create `SonicDesk.settings.json` on first run
3. If you get an execution policy error, run PowerShell as Administrator and execute:  
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
4. Double-click the script file to run, or right-click and select "Run with PowerShell"

## ⚙️ Settings Configuration

SonicDesk saves your preferences in `SonicDesk.settings.json` (created automatically in the same folder as the script).

### Settings File Location
```
[Script Folder]\SonicDesk.settings.json
```

### Settings File Structure
```json
{
    "FFprobePath": "ffprobe",
    "LastMusicFolder": "C:\\Music",
    "LastPlaylistFolder": "C:\\Music\\Playlists",
    "ExportCSV": true,
    "ExportPerFolder": false,
    "CreateRecurse": true,
    "LinuxFormat": true
}
```

### Settings Explained

| Setting | Description | Default |
|---------|-------------|---------|
| `FFprobePath` | Path to ffprobe.exe (use "ffprobe" for PATH lookup) | "ffprobe" |
| `LastMusicFolder` | Last used folder in Audio Analyzer | "" |
| `LastPlaylistFolder` | Last used folder in M3U Creator | "" |
| `ExportCSV` | Automatically export CSV after analysis | true |
| `ExportPerFolder` | Create separate CSV files per folder | false |
| `CreateRecurse` | Include subfolders when creating playlists | true |
| `LinuxFormat` | Use forward slashes in playlists | true |

### Changing Settings

**Method 1: Using the Settings Button**
1. Click the **Settings** button in the Audio Analyzer tab
2. Configure FFprobe path
3. Click "Save" - settings are saved immediately

**Method 2: Manual JSON Editing**
1. Close SonicDesk
2. Open `SonicDesk.settings.json` in any text editor
3. Modify values as needed
4. Save the file and restart SonicDesk

## 🚀 How to Use

### Audio Analyzer Tab
1. **Select a folder** containing audio files (click "Browse" or paste the path)
   - Last used folder is automatically remembered
   - Supports MP3, FLAC, WAV, OGG, and other FFprobe-compatible formats
2. **Check FFprobe status** - Look for the status indicator:
   - `[OK] FFprobe available` - Great! You'll get detailed metadata
   - `[WARNING] FFprobe not found` - Click Settings to configure FFprobe path
3. **Choose export options** (settings are remembered):
   - Export to CSV — saves analysis results  
   - Export per folder — creates separate CSV files for each subfolder  
   - Specify output filename  
4. **Click "Start Analysis"**  
5. **Use Stop button** if needed - cancels the operation gracefully
6. **View results** in the table showing metadata
7. **CSV files** will be saved in the same folder as the script (or in `Audio_Reports` folder)

### M3U Creator Tab
1. **Select source folder** containing audio files (last folder is remembered)
2. **Enter playlist name** (e.g., "my_playlist.m3u")  
3. **Choose options** (settings are remembered):
   - ✅ Include subfolders (recursive)
   - ✅ Save as Linux format (forward slashes)
4. **Click "Create Playlist"**  
5. **Use Stop button** if needed - cancels the operation gracefully
6. **Review** the list of added tracks  
7. **Playlist is saved** in the source folder with the specified name  

## 🛑 Stop Button Feature

Both the **Audio Analyzer** and **M3U Creator** tabs include a **Stop button** that allows you to cancel long-running operations at any time.

### How Stop Button Works:

1. **During Analysis/Playlist Creation**: The Stop button becomes active (red color)
2. **Click Stop**: The operation will gracefully cancel after processing the current file
3. **Results**: Any files processed up to the stop point will be displayed
4. **Export**: CSV export is skipped if cancelled (prevents partial data)

### Stop Button Behavior:

| Tab | Stop Button Location | What Happens When Clicked |
|-----|---------------------|---------------------------|
| Audio Analyzer | Next to Start button | Stops analysis, shows partial results |
| M3U Creator | Next to Create button | Stops playlist creation, saves no file |

### Visual Indicators:
- **Red Stop button** - Active and clickable during operations
- **Blue Start/Create button** - Disabled during operations
- **Status message** - Shows "Cancelling..." when stop is clicked
- **Final status** - Indicates how many files were processed before cancellation

### Benefits:
- Save time when analyzing large libraries
- Stop if you realize you selected the wrong folder
- Cancel playlist creation for huge folders
- No need to force-close the application

## 📊 Bitrate Reference

### CBR (Constant Bit Rate)

| Bitrate | Quality | Best For | File Size |
|---------|---------|----------|-----------|
| 320 kbps | Maximum | Archiving, critical listening | ~2.4 MB/min |
| 256 kbps | High | Music library | ~1.9 MB/min |
| 224 kbps | Very Good | Quality-focused collection | ~1.7 MB/min |
| 192 kbps | Good (Recommended) | General music | ~1.4 MB/min |
| 160 kbps | Fair | Casual listening | ~1.2 MB/min |
| 128 kbps | Standard | Minimum acceptable | ~0.96 MB/min |
| 96 kbps | Poor | Podcasts/audiobooks | ~0.72 MB/min |
| 64 kbps | Very Poor | Voice only | ~0.48 MB/min |

### VBR (Variable Bit Rate)

| Profile | Avg Bitrate | Quality | Use Case |
|---------|-------------|---------|----------|
| V0 | 245-285 kbps | Extreme | Professional archiving |
| V1 | 225-245 kbps | High | Critical listening |
| V2 | 190-210 kbps | Standard (Recommended) | General music |
| V3 | 170-190 kbps | Medium | Portable devices |
| V4 | 150-170 kbps | Medium-Low | Background music |

## 📁 CSV Export Format

When exporting analysis results, the CSV file includes:

| Column | Description |
|--------|-------------|
| FileName | Name of the audio file |
| FolderPath | Full path to the containing folder |
| Bitrate | Detected bitrate (e.g., "192 kbps") |
| BitrateValue | Numeric bitrate value |
| Quality | Quality rating (Very High/High/Good/Standard/Low) |
| SampleRate | Sample rate in kHz |
| Channels | Stereo or Mono |
| Duration | Track length (MM:SS) |
| Encoding | Audio encoding type (MP3/FLAC/etc.) |

## 🎯 Playlist Format Examples

### Windows Format (Linux format unchecked)
```
#EXTM3U
#EXTINF:225,My Song
Krig - Anthropos\01 - Anthropos.mp3
#EXTINF:210,Another Track
Krig - Anthropos\02 - Self Control.mp3
```

### Linux Format (Linux format checked)
```
#EXTM3U
#EXTINF:225,My Song
Krig - Anthropos/01 - Anthropos.mp3
#EXTINF:210,Another Track
Krig - Anthropos/02 - Self Control.mp3
```

## ❓ Troubleshooting

### "FFprobe not found" Warning
- **Solution**: Install FFmpeg/FFprobe using one of the methods above, then configure the path in SonicDesk Settings
- Without FFprobe, SonicDesk uses fallback methods which may not detect all metadata
- FFprobe provides the most accurate and complete metadata extraction

### Settings not saving
- Ensure you have write permissions in the script folder
- Check if `SonicDesk.settings.json` is not read-only
- Run PowerShell as Administrator if needed

### "No audio files found"
- Ensure the folder path is correct
- Verify files have supported extensions (.mp3, .flac, .wav, .ogg, etc.)
- Check that files aren't hidden

### CSV Export errors
- Ensure you have write permissions in the output folder
- Close the CSV file if it's open in another program

### Execution Policy error
Run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Stop button not working
- The Stop button only works during active operations
- Stop button is disabled when idle
- Clicking Stop will cancel after current file processing completes

## 💡 Tips

1. **Install FFprobe First** - For the best metadata extraction, install FFprobe and configure it in Settings

2. **Settings are remembered** - Your folder paths and preferences are saved automatically

3. **Use Stop button for large libraries** - Processing thousands of files may take time. Use Stop to cancel if needed

4. **Portable playlists**: Always use "Linux format" and relative paths for playlists that will be shared across devices

5. **CSV analysis**: Use the CSV export to identify low-quality files that need upgrading

6. **Per-folder exports**: Enable "Export per folder" to organize results by directory structure

## 🔧 Supported Audio Formats

SonicDesk supports any audio format that FFprobe can read, including:
- **MP3** (.mp3)
- **FLAC** (.flac)
- **WAV** (.wav)
- **OGG** (.ogg)
- **M4A** (.m4a)
- **AAC** (.aac)
- **WMA** (.wma)
- And many more...

Without FFprobe, only MP3 files are supported with limited metadata.

## 📄 License

Free for personal and commercial use.

---

**Version**: 1.0  
**Last Updated**: 2024  
**Author**: SonicDesk Team