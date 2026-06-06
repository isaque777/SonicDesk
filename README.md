Here’s the updated document with the new app name **SonicDesk** replacing all mentions of “MP3 Toolkit GUI.”  

---

# SonicDesk - README

## 📋 Overview

**SonicDesk** is a user-friendly Windows application that helps you analyze MP3 compression quality and create M3U playlists with Linux-compatible formatting. No command line required — just point and click!

## ✨ Features

### 1. MP3 Analyzer
- **Scan MP3 files** recursively through folders and subfolders  
- **Extract metadata**: Bitrate, sample rate, channels, duration  
- **Quality assessment**: Automatically evaluates compression quality (Very High to Low)  
- **Export to CSV**: Save results as CSV files (single file or per folder)  
- **Real-time progress**: See analysis progress with visual feedback  

### 2. M3U Creator
- **Create playlists** from folders containing MP3 files  
- **Relative paths only** — makes playlists portable across systems  
- **Linux format option** — converts backslashes to forward slashes  
- **Extended M3U format** — includes duration metadata  
- **Recursive scanning** — include subfolders automatically  
- **Preview before saving** — see all tracks that will be added  

### 3. Bitrate Reference Guide
- **Complete reference** for CBR and VBR bitrates  
- **Quality recommendations** for different use cases  
- **File size estimates** per minute of audio  

## 📥 Installation

### Prerequisites
- Windows 7, 8, 10, or 11  
- PowerShell 5.0 or later  
- Windows Media Player (usually pre-installed)

### Setup
1. Download `SonicDesk.ps1` to your desired location  
2. If you get an execution policy error, run PowerShell as Administrator and execute:  
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. Double-click the script file to run, or right-click and select "Run with PowerShell"

## 🚀 How to Use

### Analyzer Tab
1. **Select a folder** containing MP3 files (click "Browse" or paste the path)  
2. **Choose export options** (optional):  
   - Export to CSV — saves analysis results  
   - Export per folder — creates separate CSV files for each subfolder  
   - Specify output filename  
3. **Click "Start Analysis"**  
4. **View results** in the table showing:  
   - File name  
   - Bitrate (e.g., "192 kbps")  
   - Quality rating (Very High/High/Good/Standard/Low)  
   - Sample rate (e.g., "44.1 kHz")  
   - Channels (Stereo/Mono)  
   - Duration  
5. **CSV files** will be saved in the same folder as the script  

### Playlist Creator Tab
1. **Select source folder** containing MP3 files  
2. **Enter playlist name** (e.g., "my_music.m3u")  
3. **Choose options**:  
   - ✅ Include subfolders (recursive) — adds all MP3s from subdirectories  
   - ✅ Save as Linux format — uses forward slashes (/) instead of backslashes (\\)  
4. **Click "Create Playlist"**  
5. **Review** the list of added tracks  
6. **Playlist is saved** in the source folder with the specified name  

---

Everything else — including bitrate tables, CSV format, troubleshooting, and tips — remains unchanged, but now reflects **SonicDesk** as the product name.  

Would you like me to also update the **branding tone** (e.g., make it sound more like a modern app launch document with tagline and visuals) or keep it as a technical README?