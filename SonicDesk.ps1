# SonicDesk - Audio Management Suite
# Enhanced with FFprobe metadata extraction, settings file, and Stop buttons

# Load Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Settings file path
$settingsPath = Join-Path $PSScriptRoot "SonicDesk.settings.json"

# Default settings
$defaultSettings = @{
    FFprobePath = "ffprobe"
    LastMusicFolder = ""
    LastPlaylistFolder = ""
    ExportCSV = $true
    ExportPerFolder = $false
    CreateRecurse = $true
    LinuxFormat = $true
}

# Global flag for cancellation
$script:cancelAnalysis = $false
$script:cancelPlaylistCreation = $false

# Load or create settings
function Load-Settings {
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            Write-Host "Settings loaded from: $settingsPath" -ForegroundColor Green
            return $settings
        } catch {
            Write-Host "Error loading settings, using defaults" -ForegroundColor Yellow
            return $defaultSettings
        }
    } else {
        Write-Host "No settings file found, using defaults" -ForegroundColor Gray
        return $defaultSettings
    }
}

# Save settings
function Save-Settings {
    param($Settings)
    try {
        $settingsJson = $Settings | ConvertTo-Json -Depth 3
        Set-Content -Path $settingsPath -Value $settingsJson -Encoding UTF8
        Write-Host "Settings saved to: $settingsPath" -ForegroundColor Green
    } catch {
        Write-Host "Error saving settings: $_" -ForegroundColor Red
    }
}

# Load settings
$settings = Load-Settings

# Function to check if FFprobe is available using configured path
function Test-FFprobeAvailable {
    $ffprobeCmd = $settings.FFprobePath
    try {
        $output = & $ffprobeCmd -version 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

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

# Add Title Label (moved left)
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "SonicDesk - Audio Management Suite"
$lblTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblTitle.Width = 500
$lblTitle.Height = 30
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

$lblSubtitle = New-Object System.Windows.Forms.Label
$lblSubtitle.Text = "Professional Audio Analysis, Playlist Creation and Bitrate Reference"
$lblSubtitle.Location = New-Object System.Drawing.Point(20, 48)
$lblSubtitle.Width = 600
$lblSubtitle.Height = 20
$lblSubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblSubtitle.ForeColor = [System.Drawing.Color]::Gray

# Add Logo Picture Box (moved to right)
$picLogo = New-Object System.Windows.Forms.PictureBox
$picLogo.Width = 200
$picLogo.Height = 80
$picLogo.Location = New-Object System.Drawing.Point(980, 5)
$picLogo.SizeMode = "Zoom"

# Load header logo from file
$headerLogoPath = Join-Path $scriptPath "img\logo-croop.fw.png"
if (Test-Path $headerLogoPath) {
    $picLogo.Image = [System.Drawing.Image]::FromFile($headerLogoPath)
}

$pnlLogo.Controls.Add($lblTitle)
$pnlLogo.Controls.Add($lblSubtitle)
$pnlLogo.Controls.Add($picLogo)

# Create Tab Control
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Width = 1160
$tabControl.Height = 810
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

# Function to get audio metadata using FFprobe (most reliable)
function Get-AudioMetadata {
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
    $ffprobeOk = Test-FFprobeAvailable
    if ($ffprobeOk) {
        try {
            $ffprobeCmd = $settings.FFprobePath
            $json = & $ffprobeCmd -v error -show_format -show_streams -print_format json "$FilePath" 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
            
            if ($json -and $json.streams) {
                # Get audio stream
                $audioStream = $json.streams | Where-Object { $_.codec_type -eq "audio" } | Select-Object -First 1
                
                if ($audioStream) {
                    # Get bitrate - try multiple sources
                    if ($audioStream.bit_rate -and $audioStream.bit_rate -gt 0) {
                        $result.BitrateValue = [math]::Round([int]$audioStream.bit_rate / 1000)
                        $result.Bitrate = "$($result.BitrateValue) kbps"
                    } elseif ($json.format.bit_rate -and $json.format.bit_rate -gt 0) {
                        $result.BitrateValue = [math]::Round([int]$json.format.bit_rate / 1000)
                        $result.Bitrate = "$($result.BitrateValue) kbps"
                    } else {
                        # Calculate bitrate from file size and duration
                        if ($json.format.duration -and $json.format.duration -gt 0) {
                            $fileInfo = Get-Item $FilePath
                            $durationSec = [double]$json.format.duration
                            $bitrateCalculated = [math]::Round(($fileInfo.Length * 8) / $durationSec / 1000)
                            if ($bitrateCalculated -gt 0 -and $bitrateCalculated -lt 1000) {
                                $result.BitrateValue = $bitrateCalculated
                                $result.Bitrate = "$bitrateCalculated kbps"
                            }
                        }
                    }
                    
                    # Get sample rate
                    if ($audioStream.sample_rate -and $audioStream.sample_rate -gt 0) {
                        $sampleRateValue = [int]$audioStream.sample_rate
                        if ($sampleRateValue -ge 1000) {
                            $sampleRateKHz = [math]::Round($sampleRateValue / 1000, 1)
                            $result.SampleRate = "$sampleRateKHz kHz"
                        } else {
                            $result.SampleRate = "$sampleRateValue Hz"
                        }
                    }
                    
                    # Get channels
                    if ($audioStream.channels -and $audioStream.channels -gt 0) {
                        if ($audioStream.channels -eq 2) { $result.Channels = "Stereo" }
                        elseif ($audioStream.channels -eq 1) { $result.Channels = "Mono" }
                        else { $result.Channels = "$($audioStream.channels) Channels" }
                    }
                    
                    # Detect encoding type
                    if ($audioStream.codec_name) {
                        $result.Encoding = $audioStream.codec_name.ToUpper()
                    }
                }
                
                # Get duration
                if ($json.format.duration -and $json.format.duration -gt 0) {
                    $seconds = [math]::Floor([double]$json.format.duration)
                    $minutes = [math]::Floor($seconds / 60)
                    $secs = $seconds % 60
                    $result.Duration = "$minutes`:$($secs.ToString('00'))"
                }
            }
            
            # If we got valid data, return it
            if ($result.BitrateValue -gt 0 -or $result.Duration -ne "Unknown") {
                return $result
            }
        } catch { }
    }
    
    # Method 2: Use Shell.Application for detailed properties
    try {
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace((Split-Path $FilePath))
        $file = $folder.ParseName((Split-Path $FilePath -Leaf))
        
        # Get extended properties
        $bitrateShell = $folder.GetDetailsOf($file, 27)
        if ($bitrateShell -and $bitrateShell -match '\d+') {
            $result.BitrateValue = [int]($bitrateShell -replace '\D','')
            $result.Bitrate = "$($result.BitrateValue) kbps"
        }
        
        # Get sample rate
        $sampleRateShell = $folder.GetDetailsOf($file, 28)
        if ($sampleRateShell -and $sampleRateShell -match '\d+') {
            $sampleVal = [int]($sampleRateShell -replace '\D','')
            if ($sampleVal -ge 1000) {
                $result.SampleRate = "$([math]::Round($sampleVal/1000)) kHz"
            } else {
                $result.SampleRate = "$sampleVal Hz"
            }
        }
        
        # Get channels
        $channelsShell = $folder.GetDetailsOf($file, 30)
        if ($channelsShell) { 
            if ($channelsShell -match "2|Stereo") { $result.Channels = "Stereo" }
            elseif ($channelsShell -match "1|Mono") { $result.Channels = "Mono" }
            else { $result.Channels = $channelsShell }
        }
        
        # Get duration
        $durationShell = $folder.GetDetailsOf($file, 21)
        if ($durationShell -and $durationShell -match '\d+:\d+') {
            $result.Duration = $durationShell
        }
        
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
        return $result
    } catch { }
    
    # Method 3: Use Windows Media Player as fallback
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
        
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($media) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wmp) | Out-Null
        return $result
    } catch { }
    
    # Method 4: Calculate from file size and duration if we have duration
    if ($result.Duration -ne "Unknown" -and $result.BitrateValue -eq 0) {
        $durationParts = $result.Duration -split ':'
        if ($durationParts.Count -eq 2) {
            $durationSeconds = ([int]$durationParts[0] * 60) + [int]$durationParts[1]
            if ($durationSeconds -gt 0) {
                $fileSize = (Get-Item $FilePath).Length
                $calculatedBitrate = [math]::Round(($fileSize * 8 / 1000) / $durationSeconds)
                if ($calculatedBitrate -gt 0 -and $calculatedBitrate -lt 1000) {
                    $result.BitrateValue = $calculatedBitrate
                    $result.Bitrate = "$calculatedBitrate kbps"
                }
            }
        }
    }
    
    return $result
}

# ============================================
# TAB 1: AUDIO ANALYZER
# ============================================
$tabAnalyzer = New-Object System.Windows.Forms.TabPage
$tabAnalyzer.Text = "Audio Analyzer"
$tabAnalyzer.BackColor = [System.Drawing.Color]::White

# Folder selection
$lblAnalyzerFolder = New-Object System.Windows.Forms.Label
$lblAnalyzerFolder.Text = "Audio Folder:"
$lblAnalyzerFolder.Location = New-Object System.Drawing.Point(20, 20)
$lblAnalyzerFolder.Width = 100
$lblAnalyzerFolder.Height = 25

$txtAnalyzerFolder = New-Object System.Windows.Forms.TextBox
if ($settings.LastMusicFolder) { $txtAnalyzerFolder.Text = $settings.LastMusicFolder }
$txtAnalyzerFolder.Location = New-Object System.Drawing.Point(120, 20)
$txtAnalyzerFolder.Width = 700
$txtAnalyzerFolder.Height = 25

$btnAnalyzerBrowse = New-Object System.Windows.Forms.Button
$btnAnalyzerBrowse.Text = "Browse..."
$btnAnalyzerBrowse.Location = New-Object System.Drawing.Point(830, 18)
$btnAnalyzerBrowse.Width = 90
$btnAnalyzerBrowse.Height = 30

$btnAnalyzerBrowse.Add_Click({
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select folder containing audio files"
    if ($folderDialog.ShowDialog() -eq "OK") {
        $txtAnalyzerFolder.Text = $folderDialog.SelectedPath
        $settings.LastMusicFolder = $folderDialog.SelectedPath
        Save-Settings -Settings $settings
    }
})

# Settings button
$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = "Settings"
$btnSettings.Location = New-Object System.Drawing.Point(930, 18)
$btnSettings.Width = 70
$btnSettings.Height = 30
$btnSettings.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$btnSettings.ForeColor = [System.Drawing.Color]::White

# Settings dialog
$btnSettings.Add_Click({
    $settingsForm = New-Object System.Windows.Forms.Form
    $settingsForm.Text = "SonicDesk Settings"
    $settingsForm.Width = 500
    $settingsForm.Height = 250
    $settingsForm.StartPosition = "CenterParent"
    $settingsForm.FormBorderStyle = "FixedDialog"
    
    $lblFFprobePath = New-Object System.Windows.Forms.Label
    $lblFFprobePath.Text = "FFprobe Path:"
    $lblFFprobePath.Location = New-Object System.Drawing.Point(20, 30)
    $lblFFprobePath.Width = 100
    $lblFFprobePath.Height = 25
    
    $txtFFprobePath = New-Object System.Windows.Forms.TextBox
    $txtFFprobePath.Text = $settings.FFprobePath
    $txtFFprobePath.Location = New-Object System.Drawing.Point(130, 30)
    $txtFFprobePath.Width = 250
    $txtFFprobePath.Height = 25
    
    $btnBrowseFFprobe = New-Object System.Windows.Forms.Button
    $btnBrowseFFprobe.Text = "Browse..."
    $btnBrowseFFprobe.Location = New-Object System.Drawing.Point(390, 28)
    $btnBrowseFFprobe.Width = 80
    $btnBrowseFFprobe.Height = 25
    
    $btnBrowseFFprobe.Add_Click({
        $openDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openDialog.Title = "Select ffprobe.exe"
        $openDialog.Filter = "ffprobe.exe|ffprobe.exe|All files|*.*"
        if ($openDialog.ShowDialog() -eq "OK") {
            $txtFFprobePath.Text = $openDialog.FileName
        }
    })
    
    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = "Leave as 'ffprobe' to use system PATH, or specify full path to ffprobe.exe"
    $lblInfo.Location = New-Object System.Drawing.Point(20, 65)
    $lblInfo.Width = 450
    $lblInfo.Height = 40
    $lblInfo.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $lblInfo.ForeColor = [System.Drawing.Color]::Gray
    
    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Save"
    $btnSave.Location = New-Object System.Drawing.Point(150, 120)
    $btnSave.Width = 100
    $btnSave.Height = 30
    $btnSave.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $btnSave.ForeColor = [System.Drawing.Color]::White
    
    $btnSave.Add_Click({
        $settings.FFprobePath = $txtFFprobePath.Text
        Save-Settings -Settings $settings
        $settingsForm.Close()
        [System.Windows.Forms.MessageBox]::Show("Settings saved. Please restart SonicDesk for changes to take effect.", "Settings Saved", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })
    
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(270, 120)
    $btnCancel.Width = 100
    $btnCancel.Height = 30
    
    $btnCancel.Add_Click({ $settingsForm.Close() })
    
    $settingsForm.Controls.Add($lblFFprobePath)
    $settingsForm.Controls.Add($txtFFprobePath)
    $settingsForm.Controls.Add($btnBrowseFFprobe)
    $settingsForm.Controls.Add($lblInfo)
    $settingsForm.Controls.Add($btnSave)
    $settingsForm.Controls.Add($btnCancel)
    
    $settingsForm.ShowDialog()
})

# FFprobe status indicator
$lblFFprobeStatus = New-Object System.Windows.Forms.Label
$ffprobeAvailable = Test-FFprobeAvailable
if ($ffprobeAvailable) {
    $lblFFprobeStatus.Text = "[OK] FFprobe available - Using: $($settings.FFprobePath)"
    $lblFFprobeStatus.ForeColor = [System.Drawing.Color]::Green
} else {
    $lblFFprobeStatus.Text = "[WARNING] FFprobe not found - Current path: $($settings.FFprobePath) (Click Settings to configure)"
    $lblFFprobeStatus.ForeColor = [System.Drawing.Color]::Orange
}
$lblFFprobeStatus.Location = New-Object System.Drawing.Point(120, 50)
$lblFFprobeStatus.Width = 700
$lblFFprobeStatus.Height = 20
$lblFFprobeStatus.Font = New-Object System.Drawing.Font("Segoe UI", 8)

# Options group
$grpAnalyzerOptions = New-Object System.Windows.Forms.GroupBox
$grpAnalyzerOptions.Text = "Export Options"
$grpAnalyzerOptions.Location = New-Object System.Drawing.Point(20, 80)
$grpAnalyzerOptions.Width = 1050
$grpAnalyzerOptions.Height = 100

$chkExportCSV = New-Object System.Windows.Forms.CheckBox
$chkExportCSV.Text = "Export to CSV"
$chkExportCSV.Location = New-Object System.Drawing.Point(20, 30)
$chkExportCSV.Width = 150
$chkExportCSV.Height = 25
$chkExportCSV.Checked = $settings.ExportCSV

$chkExportCSV.Add_CheckedChanged({
    $settings.ExportCSV = $chkExportCSV.Checked
    Save-Settings -Settings $settings
})

$chkExportPerFolder = New-Object System.Windows.Forms.CheckBox
$chkExportPerFolder.Text = "Export per folder (separate CSV files)"
$chkExportPerFolder.Location = New-Object System.Drawing.Point(20, 55)
$chkExportPerFolder.Width = 250
$chkExportPerFolder.Height = 25
$chkExportPerFolder.Checked = $settings.ExportPerFolder

$chkExportPerFolder.Add_CheckedChanged({
    $settings.ExportPerFolder = $chkExportPerFolder.Checked
    Save-Settings -Settings $settings
})

$lblOutputFile = New-Object System.Windows.Forms.Label
$lblOutputFile.Text = "Output File:"
$lblOutputFile.Location = New-Object System.Drawing.Point(350, 32)
$lblOutputFile.Width = 80
$lblOutputFile.Height = 25

$txtOutputFile = New-Object System.Windows.Forms.TextBox
$txtOutputFile.Text = "Audio_Analysis.csv"
$txtOutputFile.Location = New-Object System.Drawing.Point(430, 30)
$txtOutputFile.Width = 250
$txtOutputFile.Height = 25

# Progress Bar
$progressAnalyzer = New-Object System.Windows.Forms.ProgressBar
$progressAnalyzer.Location = New-Object System.Drawing.Point(20, 200)
$progressAnalyzer.Width = 1050
$progressAnalyzer.Height = 25
$progressAnalyzer.Style = "Continuous"

# Status label
$lblAnalyzerStatus = New-Object System.Windows.Forms.Label
$lblAnalyzerStatus.Text = "Ready"
$lblAnalyzerStatus.Location = New-Object System.Drawing.Point(20, 235)
$lblAnalyzerStatus.Width = 1050
$lblAnalyzerStatus.Height = 25
$lblAnalyzerStatus.ForeColor = [System.Drawing.Color]::Blue

# Results list
$lstAnalyzerResults = New-Object System.Windows.Forms.ListView
$lstAnalyzerResults.Location = New-Object System.Drawing.Point(20, 270)
$lstAnalyzerResults.Width = 1050
$lstAnalyzerResults.Height = 430
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

# Button panel for Analyzer
$btnPanelAnalyzer = New-Object System.Windows.Forms.Panel
$btnPanelAnalyzer.Location = New-Object System.Drawing.Point(20, 720)
$btnPanelAnalyzer.Width = 300
$btnPanelAnalyzer.Height = 40

# Start button
$btnAnalyzerStart = New-Object System.Windows.Forms.Button
$btnAnalyzerStart.Text = "Start Analysis"
$btnAnalyzerStart.Location = New-Object System.Drawing.Point(0, 0)
$btnAnalyzerStart.Width = 140
$btnAnalyzerStart.Height = 40
$btnAnalyzerStart.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnAnalyzerStart.ForeColor = [System.Drawing.Color]::White
$btnAnalyzerStart.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# Stop button for Analyzer (same size, placed after Start)
$btnAnalyzerStop = New-Object System.Windows.Forms.Button
$btnAnalyzerStop.Text = "Stop"
$btnAnalyzerStop.Location = New-Object System.Drawing.Point(150, 0)
$btnAnalyzerStop.Width = 140
$btnAnalyzerStop.Height = 40
$btnAnalyzerStop.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
$btnAnalyzerStop.ForeColor = [System.Drawing.Color]::White
$btnAnalyzerStop.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnAnalyzerStop.Enabled = $false

$btnAnalyzerStop.Add_Click({
    $script:cancelAnalysis = $true
    $lblAnalyzerStatus.Text = "Cancelling... Please wait"
    $btnAnalyzerStop.Enabled = $false
    [System.Windows.Forms.Application]::DoEvents()
})

$btnPanelAnalyzer.Controls.Add($btnAnalyzerStart)
$btnPanelAnalyzer.Controls.Add($btnAnalyzerStop)

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
    $btnAnalyzerStop.Enabled = $true
    $script:cancelAnalysis = $false
    $lstAnalyzerResults.Items.Clear()
    $progressAnalyzer.Value = 0
    $lblAnalyzerStatus.Text = "Scanning for audio files..."
    [System.Windows.Forms.Application]::DoEvents()
    
    $folderPath = $txtAnalyzerFolder.Text
    $allAudioFiles = Get-ChildItem -Path $folderPath -Filter "*.mp3" -File -Recurse -ErrorAction SilentlyContinue
    
    if ($allAudioFiles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No audio files found", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        $btnAnalyzerStart.Enabled = $true
        $btnAnalyzerStop.Enabled = $false
        $lblAnalyzerStatus.Text = "Ready"
        return
    }
    
    $totalFiles = $allAudioFiles.Count
    $lblAnalyzerStatus.Text = "Found $totalFiles audio files. Analyzing..."
    [System.Windows.Forms.Application]::DoEvents()
    
    $allResults = @()
    $counter = 0
    $metadataCount = 0
    
    foreach ($file in $allAudioFiles) {
        # Check for stop request
        if ($script:cancelAnalysis) {
            $lblAnalyzerStatus.Text = "Analysis cancelled by user after processing $counter files"
            break
        }
        
        $counter = $counter + 1
        $percentComplete = ($counter / $totalFiles) * 100
        $progressAnalyzer.Value = $percentComplete
        $statusText = "Processing: " + $file.Name + " (" + $counter + " of " + $totalFiles + ")"
        $lblAnalyzerStatus.Text = $statusText
        [System.Windows.Forms.Application]::DoEvents()
        
        try {
            $info = Get-AudioMetadata -FilePath $file.FullName
            
            $bitrateValue = $info.BitrateValue
            $quality = "Unknown"
            if ($bitrateValue -ge 320) { $quality = "Very High" }
            elseif ($bitrateValue -ge 256) { $quality = "High" }
            elseif ($bitrateValue -ge 192) { $quality = "Good" }
            elseif ($bitrateValue -ge 128) { $quality = "Standard" }
            elseif ($bitrateValue -gt 0) { $quality = "Low" }
            
            if ($info.Bitrate -ne "Unknown") {
                $metadataCount = $metadataCount + 1
            }
            
            $encodingType = "Audio"
            if ($info.Encoding -ne "Unknown") { $encodingType = $info.Encoding }
            
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
            }
        }
    }
    
    # Export to CSV only if not cancelled
    if (-not $script:cancelAnalysis) {
        if ($chkExportCSV.Checked) {
            $outputFile = $txtOutputFile.Text
            $allResults | Select-Object FileName, FolderPath, Bitrate, Quality, SampleRate, Channels, Duration, Encoding | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
            $lblAnalyzerStatus.Text = "Exported to: $outputFile"
            
            # Export per folder
            if ($chkExportPerFolder.Checked) {
                $folderGroups = $allResults | Group-Object FolderPath
                $exportFolder = Join-Path $folderPath "Audio_Reports"
                if (-not (Test-Path $exportFolder)) {
                    New-Item -ItemType Directory -Path $exportFolder -Force | Out-Null
                }
                
                foreach ($folderGroup in $folderGroups) {
                    $folderName = $folderGroup.Name -replace ':', '' -replace '\\', '_' -replace '/', '_'
                    $folderOutputFile = Join-Path $exportFolder "Audio_$folderName.csv"
                    $folderGroup.Group | Select-Object FileName, Bitrate, Quality, SampleRate, Channels, Duration, Encoding | Export-Csv -Path $folderOutputFile -NoTypeInformation -Encoding UTF8
                }
                $lblAnalyzerStatus.Text = $lblAnalyzerStatus.Text + " + per-folder reports saved to 'Audio_Reports' folder"
            }
        }
        
        $resultText = "Analysis complete! Processed " + $allResults.Count + " files (" + $metadataCount + " with metadata)"
        $lblAnalyzerStatus.Text = $resultText
    } else {
        $lblAnalyzerStatus.Text = "Analysis cancelled. Processed " + $counter + " of " + $totalFiles + " files"
    }
    
    $btnAnalyzerStart.Enabled = $true
    $btnAnalyzerStop.Enabled = $false
    $script:cancelAnalysis = $false
    
    if (-not $script:cancelAnalysis -and $allResults.Count -gt 0) {
        $ffprobeMsg = ""
        if (Test-FFprobeAvailable) { $ffprobeMsg = " (FFprobe enhanced)" }
        [System.Windows.Forms.MessageBox]::Show("Analysis complete!" + "`nProcessed " + $allResults.Count + " files" + "`n" + $metadataCount + " files had readable metadata" + $ffprobeMsg, "Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

$tabAnalyzer.Controls.Add($lblAnalyzerFolder)
$tabAnalyzer.Controls.Add($txtAnalyzerFolder)
$tabAnalyzer.Controls.Add($btnAnalyzerBrowse)
$tabAnalyzer.Controls.Add($btnSettings)
$tabAnalyzer.Controls.Add($lblFFprobeStatus)
$tabAnalyzer.Controls.Add($grpAnalyzerOptions)
$grpAnalyzerOptions.Controls.Add($chkExportCSV)
$grpAnalyzerOptions.Controls.Add($chkExportPerFolder)
$grpAnalyzerOptions.Controls.Add($lblOutputFile)
$grpAnalyzerOptions.Controls.Add($txtOutputFile)
$tabAnalyzer.Controls.Add($progressAnalyzer)
$tabAnalyzer.Controls.Add($lblAnalyzerStatus)
$tabAnalyzer.Controls.Add($lstAnalyzerResults)
$tabAnalyzer.Controls.Add($btnPanelAnalyzer)

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
if ($settings.LastPlaylistFolder) { $txtSourceFolder.Text = $settings.LastPlaylistFolder }
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
    $folderDialog.Description = "Select folder containing audio files"
    if ($folderDialog.ShowDialog() -eq "OK") {
        $txtSourceFolder.Text = $folderDialog.SelectedPath
        $settings.LastPlaylistFolder = $folderDialog.SelectedPath
        Save-Settings -Settings $settings
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
$chkCreateRecurse.Checked = $settings.CreateRecurse

$chkCreateRecurse.Add_CheckedChanged({
    $settings.CreateRecurse = $chkCreateRecurse.Checked
    Save-Settings -Settings $settings
})

$chkLinuxFormat = New-Object System.Windows.Forms.CheckBox
$chkLinuxFormat.Text = "Save as Linux format (forward slashes)"
$chkLinuxFormat.Location = New-Object System.Drawing.Point(20, 130)
$chkLinuxFormat.Width = 250
$chkLinuxFormat.Height = 25
$chkLinuxFormat.Checked = $settings.LinuxFormat

$chkLinuxFormat.Add_CheckedChanged({
    $settings.LinuxFormat = $chkLinuxFormat.Checked
    Save-Settings -Settings $settings
})

$lblCreatorStatus = New-Object System.Windows.Forms.Label
$lblCreatorStatus.Text = "Ready"
$lblCreatorStatus.Location = New-Object System.Drawing.Point(20, 170)
$lblCreatorStatus.Width = 1050
$lblCreatorStatus.Height = 25
$lblCreatorStatus.ForeColor = [System.Drawing.Color]::Blue

$lstCreatorResults = New-Object System.Windows.Forms.ListBox
$lstCreatorResults.Location = New-Object System.Drawing.Point(20, 210)
$lstCreatorResults.Width = 1040
$lstCreatorResults.Height = 500
$lstCreatorResults.Font = New-Object System.Drawing.Font("Consolas", 9)

# Button panel for Creator
$btnPanelCreator = New-Object System.Windows.Forms.Panel
$btnPanelCreator.Location = New-Object System.Drawing.Point(20, 730)
$btnPanelCreator.Width = 300
$btnPanelCreator.Height = 40

# Start button
$btnCreateStart = New-Object System.Windows.Forms.Button
$btnCreateStart.Text = "Create Playlist"
$btnCreateStart.Location = New-Object System.Drawing.Point(0, 0)
$btnCreateStart.Width = 140
$btnCreateStart.Height = 40
$btnCreateStart.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnCreateStart.ForeColor = [System.Drawing.Color]::White
$btnCreateStart.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# Stop button for Creator (same size, placed after Start)
$btnCreatorStop = New-Object System.Windows.Forms.Button
$btnCreatorStop.Text = "Stop"
$btnCreatorStop.Location = New-Object System.Drawing.Point(150, 0)
$btnCreatorStop.Width = 140
$btnCreatorStop.Height = 40
$btnCreatorStop.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
$btnCreatorStop.ForeColor = [System.Drawing.Color]::White
$btnCreatorStop.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnCreatorStop.Enabled = $false

$btnCreatorStop.Add_Click({
    $script:cancelPlaylistCreation = $true
    $lblCreatorStatus.Text = "Cancelling... Please wait"
    $btnCreatorStop.Enabled = $false
    [System.Windows.Forms.Application]::DoEvents()
})

$btnPanelCreator.Controls.Add($btnCreateStart)
$btnPanelCreator.Controls.Add($btnCreatorStop)

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
    $btnCreatorStop.Enabled = $true
    $script:cancelPlaylistCreation = $false
    $lstCreatorResults.Items.Clear()
    $lblCreatorStatus.Text = "Scanning for audio files..."
    [System.Windows.Forms.Application]::DoEvents()
    
    $sourcePath = $txtSourceFolder.Text
    $outputPath = Join-Path $sourcePath $txtPlaylistName.Text
    
    if ($chkCreateRecurse.Checked) {
        $audioFiles = Get-ChildItem -Path $sourcePath -Filter "*.mp3" -File -Recurse
    } else {
        $audioFiles = Get-ChildItem -Path $sourcePath -Filter "*.mp3" -File
    }
    
    if ($audioFiles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No audio files found", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        $btnCreateStart.Enabled = $true
        $btnCreatorStop.Enabled = $false
        $lblCreatorStatus.Text = "Ready"
        return
    }
    
    $totalTracks = $audioFiles.Count
    $lstCreatorResults.Items.Add("Found $totalTracks audio files")
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
    foreach ($file in $audioFiles) {
        # Check for stop request
        if ($script:cancelPlaylistCreation) {
            $lblCreatorStatus.Text = "Playlist creation cancelled by user after $counter tracks"
            break
        }
        
        $counter = $counter + 1
        $statusText = "Processing: " + $file.Name + " (" + $counter + " of " + $totalTracks + ")"
        $lblCreatorStatus.Text = $statusText
        [System.Windows.Forms.Application]::DoEvents()
        
        # Get relative path from source folder
        $relativePath = $file.FullName.Substring($sourcePath.Length).TrimStart('\')
        
        # Convert to Linux format if requested
        if ($chkLinuxFormat.Checked) {
            $relativePath = $relativePath -replace '\\', '/'
        }
        
        # Try to get duration for extended M3U using FFprobe first
        $durationFound = $false
        $ffprobeOk = Test-FFprobeAvailable
        if ($ffprobeOk) {
            try {
                $ffprobeCmd = $settings.FFprobePath
                $json = & $ffprobeCmd -v error -show_format -print_format json "$($file.FullName)" 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($json -and $json.format.duration) {
                    $totalSeconds = [math]::Floor([double]$json.format.duration)
                    $title = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                    $playlistLines += "#EXTINF:$totalSeconds,$title"
                    $durationFound = $true
                }
            } catch { }
        }
        
        # Fallback to WMP if FFprobe failed
        if (-not $durationFound) {
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
            } catch { }
        }
        
        $playlistLines += $relativePath
        
        # Show relative path in results
        $displayPath = $relativePath
        if ($relativePath.Length -gt 90) {
            $displayPath = "..." + $relativePath.Substring($relativePath.Length - 87)
        }
        $lstCreatorResults.Items.Add("  Added: $displayPath")
        AutoScrollToListBox -ListBox $lstCreatorResults
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    # Save playlist only if not cancelled
    if (-not $script:cancelPlaylistCreation) {
        # Save playlist with UTF-8 no BOM (Linux compatible)
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines($outputPath, $playlistLines, $utf8NoBom)
        
        $lstCreatorResults.Items.Add("")
        $lstCreatorResults.Items.Add("SUCCESS: Playlist created successfully!")
        $lstCreatorResults.Items.Add("SUCCESS: Location: $outputPath")
        $lstCreatorResults.Items.Add("SUCCESS: Total tracks: $counter")
        if ($chkLinuxFormat.Checked) {
            $lstCreatorResults.Items.Add("SUCCESS: Format: Linux compatible (forward slashes)")
        }
        
        $lblCreatorStatus.Text = "Playlist created successfully! Added $counter tracks"
    } else {
        $lstCreatorResults.Items.Add("")
        $lstCreatorResults.Items.Add("CANCELLED: Playlist creation was cancelled")
        $lstCreatorResults.Items.Add("CANCELLED: Processed $counter of $totalTracks tracks")
        $lblCreatorStatus.Text = "Playlist creation cancelled after $counter tracks"
    }
    
    AutoScrollToListBox -ListBox $lstCreatorResults
    $btnCreateStart.Enabled = $true
    $btnCreatorStop.Enabled = $false
    $script:cancelPlaylistCreation = $false
    
    if (-not $script:cancelPlaylistCreation -and $counter -gt 0) {
        [System.Windows.Forms.MessageBox]::Show("Playlist created successfully!" + "`n" + $counter + " tracks added" + "`nSaved to: $outputPath", "Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
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
$tabCreator.Controls.Add($btnPanelCreator)

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
                            AUDIO BITRATE REFERENCE GUIDE
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