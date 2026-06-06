# MP3 Toolkit GUI - SonicDesk Edition
# Enhanced with FFprobe metadata extraction and logo support

# Load Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "SonicDesk - Audio Management Suite"
$form.Width = 1200
$form.Height = 950
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

# Load and set window icon from PNG
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$windowIconPath = Join-Path $scriptPath "img\logo-only.fw.png"
if (Test-Path $windowIconPath) {
    try {
        $bitmap = [System.Drawing.Bitmap]::FromFile($windowIconPath)
        $icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
        $form.Icon = $icon
    } catch {
        # Fallback if icon loading fails
    }
}

# Add Logo Panel
$pnlLogo = New-Object System.Windows.Forms.Panel
$pnlLogo.Width = 1200
$pnlLogo.Height = 90
$pnlLogo.Location = New-Object System.Drawing.Point(0, 0)
$pnlLogo.BackColor = [System.Drawing.Color]::White
$pnlLogo.BorderStyle = "FixedSingle"

# Add Logo Picture Box
$picLogo = New-Object System.Windows.Forms.PictureBox
$picLogo.Width = 90
$picLogo.Height = 80
$picLogo.Location = New-Object System.Drawing.Point(8, 5)
$picLogo.SizeMode = "Zoom"

# Load header logo from file
$headerLogoPath = Join-Path $scriptPath "img\logo-croop.fw.png"
if (Test-Path $headerLogoPath) {
    $picLogo.Image = [System.Drawing.Image]::FromFile($headerLogoPath)
}

# Add Title Label
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "SonicDesk - Audio Management Suite"
$lblTitle.Location = New-Object System.Drawing.Point(100, 15)
$lblTitle.Width = 500
$lblTitle.Height = 30
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

$lblSubtitle = New-Object System.Windows.Forms.Label
$lblSubtitle.Text = "Professional MP3 Analysis, Playlist Creation & Bitrate Reference"
$lblSubtitle.Location = New-Object System.Drawing.Point(100, 48)
$lblSubtitle.Width = 600
$lblSubtitle.Height = 20
$lblSubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblSubtitle.ForeColor = [System.Drawing.Color]::Gray

$pnlLogo.Controls.Add($picLogo)
$pnlLogo.Controls.Add($lblTitle)
$pnlLogo.Controls.Add($lblSubtitle)

# Create Tab Control
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Width = 1160
$tabControl.Height = 850
$tabControl.Location = New-Object System.Drawing.Point(10, 100)
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

# Function to auto-scroll
function AutoScrollToListView {
    param($ListView)
    if ($ListView.Items.Count -gt 0) {
        $ListView.EnsureVisible($ListView.Items.Count - 1)
    }
}

function AutoScrollToListBox {
    param($ListBox)
    if ($ListBox.Items.Count -gt 0) {
        $ListBox.TopIndex = $ListBox.Items.Count - 1
    }
}

# Function to check if FFprobe is available
function Test-FFprobeAvailable {
    try {
        $output = & ffprobe -version 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Function to get MP3 metadata using FFprobe (most reliable)
function Get-MP3Metadata {
    param([string]$FilePath)
    
    $result = @{
        Bitrate = "Unknown"
        BitrateValue = 0
        SampleRate = "Unknown"
        Channels = "Unknown"
        Duration = "Unknown"
        Encoding = "Unknown"
        Title = ""
        Artist = ""
        Album = ""
    }
    
    # Try FFprobe first (most reliable)
    if (Test-FFprobeAvailable) {
        try {
            $json = & ffprobe -v error -show_format -show_streams -print_format json "$FilePath" 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
            
            if ($json -and $json.streams) {
                # Get audio stream
                $audioStream = $json.streams | Where-Object { $_.codec_type -eq "audio" } | Select-Object -First 1
                
                if ($audioStream) {
                    # Get bitrate
                    if ($audioStream.bit_rate) {
                        $result.BitrateValue = [math]::Round([int]$audioStream.bit_rate / 1000)
                        $result.Bitrate = "$($result.BitrateValue) kbps"
                    } elseif ($json.format.bit_rate) {
                        $result.BitrateValue = [math]::Round([int]$json.format.bit_rate / 1000)
                        $result.Bitrate = "$($result.BitrateValue) kbps"
                    }
                    
                    # Get sample rate
                    if ($audioStream.sample_rate) {
                        $sampleRateKHz = [math]::Round([int]$audioStream.sample_rate / 1000)
                        $result.SampleRate = "$sampleRateKHz kHz"
                    }
                    
                    # Get channels
                    if ($audioStream.channels) {
                        if ($audioStream.channels -eq 2) { $result.Channels = "Stereo" }
                        elseif ($audioStream.channels -eq 1) { $result.Channels = "Mono" }
                        else { $result.Channels = "$($audioStream.channels)ch" }
                    }
                    
                    # Detect encoding type
                    if ($audioStream.codec_name -eq "mp3" -or $audioStream.codec_name -eq "libmp3lame") {
                        $result.Encoding = "MP3"
                    } else {
                        $result.Encoding = $audioStream.codec_name
                    }
                }
                
                # Get duration
                if ($json.format.duration) {
                    $seconds = [math]::Floor([double]$json.format.duration)
                    $minutes = [math]::Floor($seconds / 60)
                    $secs = $seconds % 60
                    $result.Duration = "$minutes`:$($secs.ToString('00'))"
                }
                
                # Get metadata tags
                if ($json.format.tags) {
                    $result.Title = $json.format.tags.title -or $json.format.tags.Title -or ""
                    $result.Artist = $json.format.tags.artist -or $json.format.tags.Artist -or ""
                    $result.Album = $json.format.tags.album -or $json.format.tags.Album -or ""
                }
            }
            return $result
        } catch { }
    }
    
    # Method 2: Use Windows Media Player as fallback
    try {
        $wmp = New-Object -ComObject "WMPlayer.OCX"
        $media = $wmp.newMedia($FilePath)
        
        # Get duration
        $duration = $media.getItemInfo("Duration")
        if ($duration -and $duration -gt 0) {
            $seconds = [math]::Floor($duration)
            $minutes = [math]::Floor($seconds / 60)
            $secs = $seconds % 60
            $result.Duration = "$minutes`:$($secs.ToString('00'))"
        }
        
        # Get bitrate
        $bitrate = $media.getItemInfo("Bitrate")
        if ($bitrate -and $bitrate -gt 0) {
            $result.BitrateValue = [math]::Round([int]$bitrate / 1000)
            $result.Bitrate = "$($result.BitrateValue) kbps"
        }
        
        # Get sample rate
        $sampleRate = $media.getItemInfo("SampleRate")
        if ($sampleRate -and $sampleRate -gt 0) {
            $sampleRateKHz = [math]::Round($sampleRate / 1000)
            $result.SampleRate = "$sampleRateKHz kHz"
        }
        
        # Get channels
        $channels = $media.getItemInfo("Channels")
        if ($channels -eq 2) { $result.Channels = "Stereo" }
        elseif ($channels -eq 1) { $result.Channels = "Mono" }
        
        $result.Encoding = "MP3"
        
        # Get title, artist, album
        $result.Title = $media.getItemInfo("Title")
        $result.Artist = $media.getItemInfo("Artist")
        $result.Album = $media.getItemInfo("Album")
        
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($media) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wmp) | Out-Null
        return $result
    } catch { }
    
    # Method 3: Use Shell.Application as fallback
    try {
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace((Split-Path $FilePath))
        $file = $folder.ParseName((Split-Path $FilePath -Leaf))
        
        # Get bitrate
        $bitrateShell = $folder.GetDetailsOf($file, 27)
        if ($bitrateShell -match '\d+') {
            $result.BitrateValue = [int]($bitrateShell -replace '\D','')
            $result.Bitrate = "$($result.BitrateValue) kbps"
        }
        
        # Get sample rate
        $sampleRateShell = $folder.GetDetailsOf($file, 28)
        if ($sampleRateShell -and $sampleRateShell -match '\d+') {
            $result.SampleRate = $sampleRateShell
        }
        
        # Get channels
        $channelsShell = $folder.GetDetailsOf($file, 30)
        if ($channelsShell) { $result.Channels = $channelsShell }
        
        $result.Encoding = "MP3"
        
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
        return $result
    } catch { }
    
    return $result
}

# ============================================
# TAB 1: MP3 ANALYZER
# ============================================
$tabAnalyzer = New-Object System.Windows.Forms.TabPage
$tabAnalyzer.Text = "MP3 Analyzer"
$tabAnalyzer.BackColor = [System.Drawing.Color]::White

# Folder selection
$lblAnalyzerFolder = New-Object System.Windows.Forms.Label
$lblAnalyzerFolder.Text = "Music Folder:"
$lblAnalyzerFolder.Location = New-Object System.Drawing.Point(20, 20)
$lblAnalyzerFolder.Width = 100
$lblAnalyzerFolder.Height = 25

$txtAnalyzerFolder = New-Object System.Windows.Forms.TextBox
$txtAnalyzerFolder.Location = New-Object System.Drawing.Point(120, 20)
$txtAnalyzerFolder.Width = 800
$txtAnalyzerFolder.Height = 25

$btnAnalyzerBrowse = New-Object System.Windows.Forms.Button
$btnAnalyzerBrowse.Text = "Browse..."
$btnAnalyzerBrowse.Location = New-Object System.Drawing.Point(930, 18)
$btnAnalyzerBrowse.Width = 100
$btnAnalyzerBrowse.Height = 30

$btnAnalyzerBrowse.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select folder containing MP3 files"
    if ($folderDialog.ShowDialog() -eq "OK") {
        $txtAnalyzerFolder.Text = $folderDialog.SelectedPath
    }
})

# Options group
$grpAnalyzerOptions = New-Object System.Windows.Forms.GroupBox
$grpAnalyzerOptions.Text = "Export Options"
$grpAnalyzerOptions.Location = New-Object System.Drawing.Point(20, 60)
$grpAnalyzerOptions.Width = 1040
$grpAnalyzerOptions.Height = 100

$chkExportCSV = New-Object System.Windows.Forms.CheckBox
$chkExportCSV.Text = "Export to CSV"
$chkExportCSV.Location = New-Object System.Drawing.Point(20, 30)
$chkExportCSV.Width = 150
$chkExportCSV.Height = 25
$chkExportCSV.Checked = $true

$chkExportPerFolder = New-Object System.Windows.Forms.CheckBox
$chkExportPerFolder.Text = "Export per folder (separate CSV files)"
$chkExportPerFolder.Location = New-Object System.Drawing.Point(20, 55)
$chkExportPerFolder.Width = 250
$chkExportPerFolder.Height = 25
$chkExportPerFolder.Checked = $false

$lblOutputFile = New-Object System.Windows.Forms.Label
$lblOutputFile.Text = "Output File:"
$lblOutputFile.Location = New-Object System.Drawing.Point(350, 32)
$lblOutputFile.Width = 80
$lblOutputFile.Height = 25

$txtOutputFile = New-Object System.Windows.Forms.TextBox
$txtOutputFile.Text = "MP3_Analysis.csv"
$txtOutputFile.Location = New-Object System.Drawing.Point(430, 30)
$txtOutputFile.Width = 250
$txtOutputFile.Height = 25

# Progress Bar
$progressAnalyzer = New-Object System.Windows.Forms.ProgressBar
$progressAnalyzer.Location = New-Object System.Drawing.Point(20, 180)
$progressAnalyzer.Width = 1040
$progressAnalyzer.Height = 25
$progressAnalyzer.Style = "Continuous"

# Status label
$lblAnalyzerStatus = New-Object System.Windows.Forms.Label
$lblAnalyzerStatus.Text = "Ready"
$lblAnalyzerStatus.Location = New-Object System.Drawing.Point(20, 215)
$lblAnalyzerStatus.Width = 1040
$lblAnalyzerStatus.Height = 25
$lblAnalyzerStatus.ForeColor = [System.Drawing.Color]::Blue

# Results list
$lstAnalyzerResults = New-Object System.Windows.Forms.ListView
$lstAnalyzerResults.Location = New-Object System.Drawing.Point(20, 250)
$lstAnalyzerResults.Width = 1040
$lstAnalyzerResults.Height = 450
$lstAnalyzerResults.View = "Details"
$lstAnalyzerResults.FullRowSelect = $true
$lstAnalyzerResults.GridLines = $true

$colFile = $lstAnalyzerResults.Columns.Add("File Name", 400)
$colBitrate = $lstAnalyzerResults.Columns.Add("Bitrate", 100)
$colQuality = $lstAnalyzerResults.Columns.Add("Quality", 100)
$colSampleRate = $lstAnalyzerResults.Columns.Add("Sample Rate", 100)
$colChannels = $lstAnalyzerResults.Columns.Add("Channels", 80)
$colDuration = $lstAnalyzerResults.Columns.Add("Duration", 80)
$colEncoding = $lstAnalyzerResults.Columns.Add("Type", 80)

# Start button
$btnAnalyzerStart = New-Object System.Windows.Forms.Button
$btnAnalyzerStart.Text = "Start Analysis"
$btnAnalyzerStart.Location = New-Object System.Drawing.Point(20, 720)
$btnAnalyzerStart.Width = 150
$btnAnalyzerStart.Height = 40
$btnAnalyzerStart.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnAnalyzerStart.ForeColor = [System.Drawing.Color]::White
$btnAnalyzerStart.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$btnAnalyzerStart.Add_Click({
    if (-not $txtAnalyzerFolder.Text) {
        [System.Windows.Forms.MessageBox]::Show("Please select a folder first", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    if (-not (Test-Path $txtAnalyzerFolder.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Folder does not exist", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    $btnAnalyzerStart.Enabled = $false
    $lstAnalyzerResults.Items.Clear()
    $progressAnalyzer.Value = 0
    $lblAnalyzerStatus.Text = "Scanning for MP3 files..."
    [System.Windows.Forms.Application]::DoEvents()
    
    $folderPath = $txtAnalyzerFolder.Text
    $allMP3Files = Get-ChildItem -Path $folderPath -Filter "*.mp3" -File -Recurse -ErrorAction SilentlyContinue
    
    if ($allMP3Files.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No MP3 files found", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        $btnAnalyzerStart.Enabled = $true
        $lblAnalyzerStatus.Text = "Ready"
        return
    }
    
    $lblAnalyzerStatus.Text = "Found $($allMP3Files.Count) MP3 files. Analyzing..."
    [System.Windows.Forms.Application]::DoEvents()
    
    $allResults = @()
    $counter = 0
    $metadataCount = 0
    
    foreach ($file in $allMP3Files) {
        $counter++
        $percentComplete = ($counter / $allMP3Files.Count) * 100
        $progressAnalyzer.Value = $percentComplete
        $lblAnalyzerStatus.Text = "Processing: $($file.Name) ($counter of $($allMP3Files.Count))"
        [System.Windows.Forms.Application]::DoEvents()
        
        try {
            $info = Get-MP3Metadata -FilePath $file.FullName
            
            $bitrateValue = $info.BitrateValue
            $quality = switch ($bitrateValue) {
                {$_ -ge 320} { "Very High" }
                {$_ -ge 256} { "High" }
                {$_ -ge 192} { "Good" }
                {$_ -ge 128} { "Standard" }
                {$_ -gt 0}  { "Low" }
                default { "Unknown" }
            }
            
            if ($info.Bitrate -ne "Unknown") {
                $metadataCount++
            }
            
            $encodingType = if ($info.Encoding -ne "Unknown") { $info.Encoding } else { "CBR" }
            
            $listItem = New-Object System.Windows.Forms.ListViewItem($file.Name)
            $listItem.SubItems.Add($info.Bitrate)
            $listItem.SubItems.Add($quality)
            $listItem.SubItems.Add($info.SampleRate)
            $listItem.SubItems.Add($info.Channels)
            $listItem.SubItems.Add($info.Duration)
            $listItem.SubItems.Add($encodingType)
            $lstAnalyzerResults.Items.Add($listItem)
            
            AutoScrollToListView -ListView $lstAnalyzerResults
            
            $allResults += [PSCustomObject]@{
                FileName = $file.Name
                FolderPath = $file.DirectoryName
                Bitrate = $info.Bitrate
                BitrateValue = $bitrateValue
                Quality = $quality
                SampleRate = $info.SampleRate
                Channels = $info.Channels
                Duration = $info.Duration
                Encoding = $encodingType
                Title = $info.Title
                Artist = $info.Artist
                Album = $info.Album
            }
        }
        catch {
            $listItem = New-Object System.Windows.Forms.ListViewItem($file.Name)
            $listItem.SubItems.Add("Error")
            $listItem.SubItems.Add("Unknown")
            $listItem.SubItems.Add("-")
            $listItem.SubItems.Add("-")
            $listItem.SubItems.Add("-")
            $listItem.SubItems.Add("-")
            $lstAnalyzerResults.Items.Add($listItem)
            AutoScrollToListView -ListView $lstAnalyzerResults
            
            $allResults += [PSCustomObject]@{
                FileName = $file.Name
                FolderPath = $file.DirectoryName
                Bitrate = "Error"
                BitrateValue = 0
                Quality = "Unknown"
                SampleRate = "-"
                Channels = "-"
                Duration = "-"
                Encoding = "-"
                Title = ""
                Artist = ""
                Album = ""
            }
        }
    }
    
    # Export to CSV
    if ($chkExportCSV.Checked) {
        $outputFile = $txtOutputFile.Text
        $allResults | Select-Object FileName, FolderPath, Bitrate, Quality, SampleRate, Channels, Duration, Encoding | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
        $lblAnalyzerStatus.Text = "Exported to: $outputFile"
        
        # Export per folder (fixed filename issue)
        if ($chkExportPerFolder.Checked) {
            $folderGroups = $allResults | Group-Object FolderPath
            $exportFolder = Join-Path $folderPath "MP3_Reports"
            if (-not (Test-Path $exportFolder)) {
                New-Item -ItemType Directory -Path $exportFolder -Force | Out-Null
            }
            
            foreach ($folderGroup in $folderGroups) {
                $folderName = $folderGroup.Name -replace ':', '' -replace '\\', '_' -replace '/', '_'
                $folderOutputFile = Join-Path $exportFolder "MP3_$folderName.csv"
                $folderGroup.Group | Select-Object FileName, Bitrate, Quality, SampleRate, Channels, Duration, Encoding | Export-Csv -Path $folderOutputFile -NoTypeInformation -Encoding UTF8
            }
            $lblAnalyzerStatus.Text += " + per-folder reports saved to 'MP3_Reports' folder"
        }
    }
    
    $lblAnalyzerStatus.Text = "Analysis complete! Processed $($allResults.Count) files ($metadataCount with metadata)"
    $btnAnalyzerStart.Enabled = $true
    [System.Windows.Forms.MessageBox]::Show("Analysis complete!`nProcessed $($allResults.Count) files`n$metadataCount files had readable metadata", "Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$tabAnalyzer.Controls.Add($lblAnalyzerFolder)
$tabAnalyzer.Controls.Add($txtAnalyzerFolder)
$tabAnalyzer.Controls.Add($btnAnalyzerBrowse)
$tabAnalyzer.Controls.Add($grpAnalyzerOptions)
$grpAnalyzerOptions.Controls.Add($chkExportCSV)
$grpAnalyzerOptions.Controls.Add($chkExportPerFolder)
$grpAnalyzerOptions.Controls.Add($lblOutputFile)
$grpAnalyzerOptions.Controls.Add($txtOutputFile)
$tabAnalyzer.Controls.Add($progressAnalyzer)
$tabAnalyzer.Controls.Add($lblAnalyzerStatus)
$tabAnalyzer.Controls.Add($lstAnalyzerResults)
$tabAnalyzer.Controls.Add($btnAnalyzerStart)

# ============================================
# TAB 2: M3U CREATOR
# ============================================
$tabCreator = New-Object System.Windows.Forms.TabPage
$tabCreator.Text = "M3U Creator"
$tabCreator.BackColor = [System.Drawing.Color]::White

$lblSourceFolder = New-Object System.Windows.Forms.Label
$lblSourceFolder.Text = "Source Folder:"
$lblSourceFolder.Location = New-Object System.Drawing.Point(20, 20)
$lblSourceFolder.Width = 100
$lblSourceFolder.Height = 25

$txtSourceFolder = New-Object System.Windows.Forms.TextBox
$txtSourceFolder.Location = New-Object System.Drawing.Point(120, 20)
$txtSourceFolder.Width = 800
$txtSourceFolder.Height = 25

$btnSourceBrowse = New-Object System.Windows.Forms.Button
$btnSourceBrowse.Text = "Browse..."
$btnSourceBrowse.Location = New-Object System.Drawing.Point(930, 18)
$btnSourceBrowse.Width = 100
$btnSourceBrowse.Height = 30

$btnSourceBrowse.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select folder containing MP3 files"
    if ($folderDialog.ShowDialog() -eq "OK") {
        $txtSourceFolder.Text = $folderDialog.SelectedPath
    }
})

$lblPlaylistName = New-Object System.Windows.Forms.Label
$lblPlaylistName.Text = "Playlist Name:"
$lblPlaylistName.Location = New-Object System.Drawing.Point(20, 60)
$lblPlaylistName.Width = 100
$lblPlaylistName.Height = 25

$txtPlaylistName = New-Object System.Windows.Forms.TextBox
$txtPlaylistName.Text = "playlist.m3u"
$txtPlaylistName.Location = New-Object System.Drawing.Point(120, 60)
$txtPlaylistName.Width = 300
$txtPlaylistName.Height = 25

$chkCreateRecurse = New-Object System.Windows.Forms.CheckBox
$chkCreateRecurse.Text = "Include subfolders (recursive)"
$chkCreateRecurse.Location = New-Object System.Drawing.Point(20, 100)
$chkCreateRecurse.Width = 250
$chkCreateRecurse.Height = 25
$chkCreateRecurse.Checked = $true

$chkLinuxFormat = New-Object System.Windows.Forms.CheckBox
$chkLinuxFormat.Text = "Save as Linux format (forward slashes)"
$chkLinuxFormat.Location = New-Object System.Drawing.Point(20, 130)
$chkLinuxFormat.Width = 250
$chkLinuxFormat.Height = 25
$chkLinuxFormat.Checked = $true

$lblCreatorStatus = New-Object System.Windows.Forms.Label
$lblCreatorStatus.Text = "Ready"
$lblCreatorStatus.Location = New-Object System.Drawing.Point(20, 170)
$lblCreatorStatus.Width = 1040
$lblCreatorStatus.Height = 25
$lblCreatorStatus.ForeColor = [System.Drawing.Color]::Blue

$lstCreatorResults = New-Object System.Windows.Forms.ListBox
$lstCreatorResults.Location = New-Object System.Drawing.Point(20, 210)
$lstCreatorResults.Width = 1040
$lstCreatorResults.Height = 500
$lstCreatorResults.Font = New-Object System.Drawing.Font("Consolas", 9)

$btnCreateStart = New-Object System.Windows.Forms.Button
$btnCreateStart.Text = "Create Playlist"
$btnCreateStart.Location = New-Object System.Drawing.Point(20, 730)
$btnCreateStart.Width = 150
$btnCreateStart.Height = 40
$btnCreateStart.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnCreateStart.ForeColor = [System.Drawing.Color]::White
$btnCreateStart.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$btnCreateStart.Add_Click({
    if (-not $txtSourceFolder.Text) {
        [System.Windows.Forms.MessageBox]::Show("Please select a source folder first", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    if (-not (Test-Path $txtSourceFolder.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Folder does not exist", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    $btnCreateStart.Enabled = $false
    $lstCreatorResults.Items.Clear()
    $lblCreatorStatus.Text = "Scanning for MP3 files..."
    [System.Windows.Forms.Application]::DoEvents()
    
    $sourcePath = $txtSourceFolder.Text
    $outputPath = Join-Path $sourcePath $txtPlaylistName.Text
    
    if ($chkCreateRecurse.Checked) {
        $mp3Files = Get-ChildItem -Path $sourcePath -Filter "*.mp3" -File -Recurse
    } else {
        $mp3Files = Get-ChildItem -Path $sourcePath -Filter "*.mp3" -File
    }
    
    if ($mp3Files.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No MP3 files found", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        $btnCreateStart.Enabled = $true
        $lblCreatorStatus.Text = "Ready"
        return
    }
    
    $lstCreatorResults.Items.Add("Found $($mp3Files.Count) MP3 files")
    $lstCreatorResults.Items.Add("Creating playlist: $outputPath")
    if ($chkLinuxFormat.Checked) {
        $lstCreatorResults.Items.Add("Format: Linux (forward slashes)")
    } else {
        $lstCreatorResults.Items.Add("Format: Windows (backslashes)")
    }
    $lstCreatorResults.Items.Add("")
    AutoScrollToListBox -ListBox $lstCreatorResults
    [System.Windows.Forms.Application]::DoEvents()
    
    $playlistLines = @()
    $playlistLines += "#EXTM3U"
    
    $counter = 0
    foreach ($file in $mp3Files) {
        $counter++
        $lblCreatorStatus.Text = "Processing: $($file.Name) ($counter of $($mp3Files.Count))"
        [System.Windows.Forms.Application]::DoEvents()
        
        # Get relative path from source folder
        $relativePath = $file.FullName.Substring($sourcePath.Length).TrimStart('\')
        
        # Convert to Linux format if requested
        if ($chkLinuxFormat.Checked) {
            $relativePath = $relativePath -replace '\\', '/'
        }
        
        # Try to get duration for extended M3U
        try {
            $wmp = New-Object -ComObject "WMPlayer.OCX"
            $media = $wmp.newMedia($file.FullName)
            $duration = $media.getItemInfo("Duration")
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($media) | Out-Null
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wmp) | Out-Null
            
            if ($duration -and $duration -gt 0) {
                $totalSeconds = [math]::Floor($duration)
                $title = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                $playlistLines += "#EXTINF:$totalSeconds,$title"
            }
        } catch {
            # Skip if can't get duration
        }
        
        $playlistLines += $relativePath
        
        # Show relative path in results
        $displayPath = if ($relativePath.Length -gt 90) { "..." + $relativePath.Substring($relativePath.Length - 87) } else { $relativePath }
        $lstCreatorResults.Items.Add("  Added: $displayPath")
        AutoScrollToListBox -ListBox $lstCreatorResults
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    # Save playlist with UTF-8 no BOM (Linux compatible)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($outputPath, $playlistLines, $utf8NoBom)
    
    $lstCreatorResults.Items.Add("")
    $lstCreatorResults.Items.Add("SUCCESS: Playlist created successfully!")
    $lstCreatorResults.Items.Add("SUCCESS: Location: $outputPath")
    $lstCreatorResults.Items.Add("SUCCESS: Total tracks: $($mp3Files.Count)")
    if ($chkLinuxFormat.Checked) {
        $lstCreatorResults.Items.Add("SUCCESS: Format: Linux compatible (forward slashes)")
    }
    AutoScrollToListBox -ListBox $lstCreatorResults
    
    $lblCreatorStatus.Text = "Playlist created successfully! Added $($mp3Files.Count) tracks"
    $btnCreateStart.Enabled = $true
    [System.Windows.Forms.MessageBox]::Show("Playlist created successfully!`n$($mp3Files.Count) tracks added`nSaved to: $outputPath", "Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$tabCreator.Controls.Add($lblSourceFolder)
$tabCreator.Controls.Add($txtSourceFolder)
$tabCreator.Controls.Add($btnSourceBrowse)
$tabCreator.Controls.Add($lblPlaylistName)
$tabCreator.Controls.Add($txtPlaylistName)
$tabCreator.Controls.Add($chkCreateRecurse)
$tabCreator.Controls.Add($chkLinuxFormat)
$tabCreator.Controls.Add($lblCreatorStatus)
$tabCreator.Controls.Add($lstCreatorResults)
$tabCreator.Controls.Add($btnCreateStart)

# ============================================
# TAB 3: BITRATE REFERENCE
# ============================================
$tabReference = New-Object System.Windows.Forms.TabPage
$tabReference.Text = "Bitrate Reference"
$tabReference.BackColor = [System.Drawing.Color]::White

$txtReference = New-Object System.Windows.Forms.RichTextBox
$txtReference.Location = New-Object System.Drawing.Point(20, 20)
$txtReference.Width = 1040
$txtReference.Height = 770
$txtReference.ReadOnly = $true
$txtReference.Font = New-Object System.Drawing.Font("Consolas", 10)
$txtReference.BackColor = [System.Drawing.Color]::White

$referenceText = @"
================================================================================
                            MP3 BITRATE REFERENCE GUIDE
================================================================================

CBR (Constant Bit Rate) - Fixed bitrate throughout the file
--------------------------------------------------------------------------------

  320 kbps  ....................  Maximum Quality
                                  Virtually indistinguishable from CD
                                  Best for archiving and critical listening
                                  File size: ~2.4 MB per minute

  256 kbps  ....................  High Quality
                                  Excellent for music library
                                  Good balance of quality and size
                                  File size: ~1.9 MB per minute

  224 kbps  ....................  Very Good Quality
                                  High quality, good for most listeners
                                  File size: ~1.7 MB per minute

  192 kbps  ....................  Good Quality (RECOMMENDED)
                                  Sweet spot for quality vs file size
                                  Standard for most music collections
                                  File size: ~1.4 MB per minute

  160 kbps  ....................  Fair Quality
                                  Decent for casual listening
                                  File size: ~1.2 MB per minute

  128 kbps  ....................  Standard Quality
                                  Minimum acceptable for music
                                  Noticeable artifacts in some music
                                  File size: ~0.96 MB per minute

   96 kbps  ....................  Poor Quality
                                  Significant quality loss
                                  Suitable for podcasts/audiobooks only
                                  File size: ~0.72 MB per minute

   64 kbps  ....................  Very Poor Quality
                                  Voice quality only
                                  Not recommended for music
                                  File size: ~0.48 MB per minute

--------------------------------------------------------------------------------
VBR (Variable Bit Rate) - Quality-based encoding
--------------------------------------------------------------------------------

  V0        ....................  Extreme Quality (245-285 kbps avg)
                                  Best VBR quality, nearly transparent

  V1        ....................  High Quality (225-245 kbps avg)
                                  Excellent for critical listening

  V2        ....................  Standard Quality (190-210 kbps avg)
                                  RECOMMENDED - Best balance for music

  V3        ....................  Medium Quality (170-190 kbps avg)
                                  Good for portable devices

  V4        ....................  Medium-Low Quality (150-170 kbps avg)
                                  Acceptable for background music

--------------------------------------------------------------------------------
RECOMMENDATIONS
--------------------------------------------------------------------------------

  * For archiving:         320 kbps CBR or V0
  * For music library:     192-256 kbps CBR or V2
  * For portable devices:  128-192 kbps CBR or V3-V4
  * For podcasts/speech:   64-96 kbps

================================================================================
"@

$txtReference.Text = $referenceText
$tabReference.Controls.Add($txtReference)

# Add tabs to tab control
$tabControl.Controls.Add($tabAnalyzer)
$tabControl.Controls.Add($tabCreator)
$tabControl.Controls.Add($tabReference)

# Add controls to form
$form.Controls.Add($pnlLogo)
$form.Controls.Add($tabControl)

# Show the form
$form.Add_Shown({ $form.Activate() })
[System.Windows.Forms.Application]::Run($form)