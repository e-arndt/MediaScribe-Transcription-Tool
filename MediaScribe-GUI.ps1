# =====================================================
# MediaScribe-GUI.ps1
# Phase 2 GUI wrapper for transcribe.ps1
# =====================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Allow only one MediaScribe GUI instance in the current Windows logon session.
$script:SingleInstanceMutex = $null
$script:OwnsSingleInstanceMutex = $false
$singleInstanceMutexName = "Local\MediaScribe.GUI.SingleInstance"
$singleInstanceCreatedNew = $false

try {
    $script:SingleInstanceMutex = [System.Threading.Mutex]::new(
        $true,
        $singleInstanceMutexName,
        [ref]$singleInstanceCreatedNew
    )

    $script:OwnsSingleInstanceMutex = $singleInstanceCreatedNew
} catch {
    # If Windows cannot create the mutex, continue rather than blocking MediaScribe.
    $script:SingleInstanceMutex = $null
    $script:OwnsSingleInstanceMutex = $false
    $singleInstanceCreatedNew = $true
}

if (-not $singleInstanceCreatedNew) {
    $duplicateInstanceOwner = $null

    try {
        # Give the warning a temporary TopMost owner so it cannot be hidden
        # behind the support terminal opened by the duplicate launch.
        $duplicateInstanceOwner = New-Object System.Windows.Forms.Form
        $duplicateInstanceOwner.Text = "MediaScribe"
        $duplicateInstanceOwner.ShowInTaskbar = $false
        $duplicateInstanceOwner.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
        $duplicateInstanceOwner.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $duplicateInstanceOwner.Size = New-Object System.Drawing.Size(1, 1)
        $duplicateInstanceOwner.Opacity = 0.01
        $duplicateInstanceOwner.TopMost = $true

        $duplicateInstanceOwner.Show()
        $duplicateInstanceOwner.Activate()
        $duplicateInstanceOwner.BringToFront()
        [System.Windows.Forms.Application]::DoEvents()

        [System.Windows.Forms.MessageBox]::Show(
            $duplicateInstanceOwner,
            "MediaScribe is already running.`r`n`r`nCheck the taskbar for the open MediaScribe window.`r`nOnly one MediaScribe GUI instance can run at a time.",
            "MediaScribe Already Running",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } finally {
        if ($null -ne $duplicateInstanceOwner) {
            try {
                $duplicateInstanceOwner.Close()
            } catch {
                # Ignore temporary owner shutdown errors.
            }

            try {
                $duplicateInstanceOwner.Dispose()
            } catch {
                # Ignore temporary owner disposal errors.
            }
        }

        if ($null -ne $script:SingleInstanceMutex) {
            $script:SingleInstanceMutex.Dispose()
            $script:SingleInstanceMutex = $null
        }
    }

    return
}

function Release-MediaScribeSingleInstanceMutex {
    if ($null -eq $script:SingleInstanceMutex) {
        return
    }

    if ($script:OwnsSingleInstanceMutex) {
        try {
            $script:SingleInstanceMutex.ReleaseMutex()
        } catch {
            # The mutex may already have been released during shutdown.
        }
    }

    try {
        $script:SingleInstanceMutex.Dispose()
    } catch {
        # Ignore mutex disposal errors during shutdown.
    }

    $script:SingleInstanceMutex = $null
    $script:OwnsSingleInstanceMutex = $false
}

function Initialize-MediaScribeGuiUtf8Output {
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false

        [Console]::OutputEncoding = $utf8NoBom
        [Console]::InputEncoding = $utf8NoBom

        $script:OutputEncoding = $utf8NoBom
        $global:OutputEncoding = $utf8NoBom
    } catch {
        # Ignore encoding setup errors.
    }

    # Child PowerShell / Python / Whisper processes inherit these.
    $env:PYTHONIOENCODING = "utf-8"
    $env:PYTHONUTF8 = "1"
    $env:PYTHONUNBUFFERED = "1"
}

Initialize-MediaScribeGuiUtf8Output

# Set the minimized support window title.
$host.UI.RawUI.WindowTitle = "DO NOT CLOSE - MediaScribe Support Window"

# Minimize only the PowerShell console window, not the MediaScribe GUI.
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class MediaScribeConsoleWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

$consoleHandle = [MediaScribeConsoleWindow]::GetConsoleWindow()
if ($consoleHandle -ne [IntPtr]::Zero) {
    # 6 = SW_MINIMIZE
    [MediaScribeConsoleWindow]::ShowWindow($consoleHandle, 6) | Out-Null
}

# -----------------------------
# GUI fonts
# -----------------------------

$fontMain = New-Object System.Drawing.Font("Segoe UI", 11)
$fontHeader = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$fontSubtitle = New-Object System.Drawing.Font("Segoe UI", 11)
$fontSection = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$fontButton = New-Object System.Drawing.Font("Segoe UI", 10)
$fontButtonBold = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontStatus = New-Object System.Drawing.Font("Consolas", 10)

# -----------------------------
# GUI colors
# -----------------------------

# Main window: warm, low-glare neutral
$colorFormBackground = [System.Drawing.Color]::FromArgb(171, 147, 120)

# Group boxes: lighter complementary surface
$colorPanelBackground = [System.Drawing.Color]::FromArgb(209, 190, 167)

# Text boxes, dropdowns, and status area
$colorInputBackground = [System.Drawing.Color]::FromArgb(250, 249, 246)

# Text colors
$colorPrimaryText = [System.Drawing.Color]::FromArgb(51, 6, 8)
$colorSecondaryText = [System.Drawing.Color]::FromArgb(8, 4, 4)
$colorGroupText = [System.Drawing.Color]::FromArgb(179, 30, 37)

# Neutral buttons
$colorButtonBackground = [System.Drawing.Color]::FromArgb(237, 221, 199)
$colorButtonHover = [System.Drawing.Color]::FromArgb(199, 152, 78)
$colorButtonDown = [System.Drawing.Color]::FromArgb(187, 202, 199)
$colorButtonText = [System.Drawing.Color]::FromArgb(25, 38, 40)
$colorButtonBorder = [System.Drawing.Color]::FromArgb(90, 110, 112)

# Primary Start button
$colorStopRed = $colorGroupText
$colorStartGreen = [System.Drawing.Color]::FromArgb(0, 128, 64)
$colorStartGreenHover = [System.Drawing.Color]::FromArgb(0, 112, 57)
$colorStartGreenDown = [System.Drawing.Color]::FromArgb(0, 95, 49)

# -----------------------------
# Paths and config
# -----------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TranscribeScript = Join-Path $ScriptDir "transcribe.ps1"
$ConfigPath = Join-Path $ScriptDir "config.json"

$InputDir = Join-Path $ScriptDir "Input"
$OutputDir = Join-Path $ScriptDir "Output"
$DefaultModel = "medium"
$DefaultLanguage = "en"

if (Test-Path -LiteralPath $ConfigPath) {
    try {
        $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

        if ($config.InputFolder) {
            if ([System.IO.Path]::IsPathRooted($config.InputFolder)) {
                $InputDir = $config.InputFolder
            } else {
                $InputDir = Join-Path $ScriptDir $config.InputFolder
            }
        }

        if ($config.OutputFolder) {
            if ([System.IO.Path]::IsPathRooted($config.OutputFolder)) {
                $OutputDir = $config.OutputFolder
            } else {
                $OutputDir = Join-Path $ScriptDir $config.OutputFolder
            }
        }

        if ($config.DefaultModel) {
            $DefaultModel = $config.DefaultModel
        }

        if ($config.DefaultLanguage) {
            $DefaultLanguage = $config.DefaultLanguage
        }
    } catch {
        # Use built-in defaults if config cannot be read.
    }
}

foreach ($folder in @($InputDir, $OutputDir)) {
    if (-not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
}

$RecognizedExtensions = @(
    ".mp4", ".mkv", ".mov", ".m4v", ".avi", ".webm",
    ".mp3", ".m4a", ".wav", ".aac", ".flac", ".ogg", ".opus", ".wma"
)

$LanguageOptions = [ordered]@{
    "English"     = "en"
    "Auto-detect" = "auto"
    "Chinese"     = "zh"
    "French"      = "fr"
    "German"      = "de"
    "Italian"     = "it"
    "Japanese"    = "ja"
    "Korean"      = "ko"
    "Portuguese"  = "pt"
    "Spanish"     = "es"
}

$OutputTextOptions = [ordered]@{
    "Same as input / detected" = "same"
    "English translation"      = "english"
}

function Get-LanguageNameFromCode {
    param([string]$LanguageCode)

    if ([string]::IsNullOrWhiteSpace($LanguageCode)) {
        return "English"
    }

    foreach ($entry in $LanguageOptions.GetEnumerator()) {
        if ($entry.Value -eq $LanguageCode) {
            return $entry.Key
        }
    }

    return "English"
}

$script:SourceFolder = $InputDir

function Get-MediaFilesFromFolder {
    param([string]$FolderPath)

    if ([string]::IsNullOrWhiteSpace($FolderPath) -or -not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
        return @()
    }

    return Get-ChildItem -LiteralPath $FolderPath -File -ErrorAction SilentlyContinue |
        Where-Object { $RecognizedExtensions -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object Name
}

function Update-FileList {
    param([string]$FolderPath)

    if ([string]::IsNullOrWhiteSpace($FolderPath) -or -not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Choose a valid source folder.",
            "MediaScribe",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    $script:SourceFolder = $FolderPath
    $sourceFolderTextBox.Text = $FolderPath

    $fileCombo.Items.Clear()
    $mediaFiles = @(Get-MediaFilesFromFolder -FolderPath $FolderPath)

    foreach ($mediaFile in $mediaFiles) {
        [void]$fileCombo.Items.Add($mediaFile.Name)
    }

    $allFilesRadioButton.Text = "All recognized files in source folder ($($mediaFiles.Count))"

    if ($fileCombo.Items.Count -gt 0) {
        $fileCombo.SelectedIndex = 0
        $statusLabel.Text = "Status: Ready"
    } else {
        $statusLabel.Text = "Status: No recognized media files found"
    }

    Update-FileSelectionMode
}

function Get-SelectedMediaFile {
    if ([string]::IsNullOrWhiteSpace($script:SourceFolder)) {
        return $null
    }

    if ($null -eq $fileCombo.SelectedItem) {
        return $null
    }

    return Join-Path $script:SourceFolder $fileCombo.SelectedItem.ToString()
}

function Update-FileSelectionMode {
    $batchModeSelected = $allFilesRadioButton.Checked

    if (-not $script:IsRunning) {
        $fileCombo.Enabled = -not $batchModeSelected
    } else {
        $fileCombo.Enabled = $false
    }

    if ($batchModeSelected) {
        $startButton.Text = "Start Batch Transcription"
    } else {
        $startButton.Text = "Start Transcription"
    }
}

function Add-Status {
    param([string]$Text)

    if ($null -eq $Text) {
        return
    }

    $statusBox.AppendText($Text + [Environment]::NewLine)
    $statusBox.SelectionStart = $statusBox.Text.Length
    $statusBox.ScrollToCaret()
}

function Update-StopButtonAppearance {
    if ($null -eq $stopButton) {
        return
    }

    if ($script:IsRunning -and -not $script:StopRequested) {
        $stopButton.Enabled = $true
        $stopButton.Text = "Stop Transcription"
        $stopButton.UseVisualStyleBackColor = $false
        $stopButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $stopButton.BackColor = $colorStopRed
        $stopButton.ForeColor = [System.Drawing.Color]::White
        $stopButton.FlatAppearance.BorderSize = 1
        $stopButton.FlatAppearance.BorderColor = $colorStopRed
        $stopButton.FlatAppearance.MouseOverBackColor = $colorStopRed
        $stopButton.FlatAppearance.MouseDownBackColor = $colorStopRed
    } elseif ($script:IsRunning -and $script:StopRequested) {
        $stopButton.Enabled = $false
        $stopButton.Text = "Stopping..."
        $stopButton.BackColor = $colorButtonBackground
        $stopButton.ForeColor = $colorButtonText
        $stopButton.FlatAppearance.BorderColor = $colorButtonBorder
    } else {
        $stopButton.Enabled = $false
        $stopButton.Text = "Stop Transcription"
        $stopButton.BackColor = $colorButtonBackground
        $stopButton.ForeColor = $colorButtonText
        $stopButton.FlatAppearance.BorderColor = $colorButtonBorder
    }
}

function Set-RunningState {
    param([bool]$IsRunning)

    $script:IsRunning = $IsRunning

    $browseFolderButton.Enabled = -not $IsRunning
    $refreshFilesButton.Enabled = -not $IsRunning
    $selectedFileRadioButton.Enabled = -not $IsRunning
    $allFilesRadioButton.Enabled = -not $IsRunning
    $fileCombo.Enabled = $false
    $startButton.Enabled = -not $IsRunning
    $outputModeCombo.Enabled = -not $IsRunning
    $modelCombo.Enabled = -not $IsRunning
    $languageCombo.Enabled = -not $IsRunning
    $outputTextCombo.Enabled = -not $IsRunning
    $openInputButton.Enabled = -not $IsRunning
    $openOutputButton.Enabled = -not $IsRunning
    $clearStatusButton.Enabled = -not $IsRunning

    if ($IsRunning) {
        $statusLabel.Text = "Status: Running"
    } else {
        $script:StopRequested = $false
        Update-FileSelectionMode
        $statusLabel.Text = "Status: Ready"
    }

    Update-StopButtonAppearance
}

# -----------------------------
# Form
# -----------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "MediaScribe"
$form.Size = New-Object System.Drawing.Size(880, 930)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(860, 775)
$form.WindowState = "Normal"
$form.ShowInTaskbar = $true
$form.BackColor = $colorFormBackground

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "MediaScribe"
$titleLabel.Font = $fontHeader
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$titleLabel.Size = New-Object System.Drawing.Size(820, 42)
$form.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Create transcripts and optional caption files from audio/video files."
$subtitleLabel.Font = $fontSubtitle
$subtitleLabel.Location = New-Object System.Drawing.Point(22, 58)
$subtitleLabel.Size = New-Object System.Drawing.Size(820, 28)
$form.Controls.Add($subtitleLabel)

# -----------------------------
# Group boxes
# -----------------------------

$filesGroup = New-Object System.Windows.Forms.GroupBox
$filesGroup.Text = "Files"
$filesGroup.Font = $fontSection
$filesGroup.Location = New-Object System.Drawing.Point(20, 95)
$filesGroup.Size = New-Object System.Drawing.Size(825, 155)
$filesGroup.BackColor = $colorPanelBackground
$filesGroup.ForeColor = $colorGroupText
$form.Controls.Add($filesGroup)

$settingsGroup = New-Object System.Windows.Forms.GroupBox
$settingsGroup.Text = "Transcription Settings"
$settingsGroup.Font = $fontSection
$settingsGroup.Location = New-Object System.Drawing.Point(20, 275)
$settingsGroup.Size = New-Object System.Drawing.Size(825, 165)
$settingsGroup.BackColor = $colorPanelBackground
$settingsGroup.ForeColor = $colorGroupText
$form.Controls.Add($settingsGroup)

$statusGroup = New-Object System.Windows.Forms.GroupBox
$statusGroup.Text = "Status"
$statusGroup.Font = $fontSection
$statusGroup.Location = New-Object System.Drawing.Point(20, 525)
$statusGroup.Size = New-Object System.Drawing.Size(825, 310)
$statusGroup.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Top `
    -bor [System.Windows.Forms.AnchorStyles]::Bottom `
    -bor [System.Windows.Forms.AnchorStyles]::Left `
    -bor [System.Windows.Forms.AnchorStyles]::Right
)
$statusGroup.BackColor = $colorPanelBackground
$statusGroup.ForeColor = $colorGroupText
$form.Controls.Add($statusGroup)

# -----------------------------
# Files group controls
# -----------------------------

$sourceFolderLabel = New-Object System.Windows.Forms.Label
$sourceFolderLabel.Text = "Source folder:"
$sourceFolderLabel.Font = $fontSection
$sourceFolderLabel.Location = New-Object System.Drawing.Point(15, 28)
$sourceFolderLabel.Size = New-Object System.Drawing.Size(160, 25)
$filesGroup.Controls.Add($sourceFolderLabel)

$sourceFolderTextBox = New-Object System.Windows.Forms.TextBox
$sourceFolderTextBox.Font = $fontMain
$sourceFolderTextBox.Location = New-Object System.Drawing.Point(15, 55)
$sourceFolderTextBox.Size = New-Object System.Drawing.Size(520, 27)
$sourceFolderTextBox.ReadOnly = $true
$filesGroup.Controls.Add($sourceFolderTextBox)

$browseFolderButton = New-Object System.Windows.Forms.Button
$browseFolderButton.Text = "Browse Folder..."
$browseFolderButton.Font = $fontButton
$browseFolderButton.Location = New-Object System.Drawing.Point(545, 53)
$browseFolderButton.Size = New-Object System.Drawing.Size(135, 32)
$filesGroup.Controls.Add($browseFolderButton)

$refreshFilesButton = New-Object System.Windows.Forms.Button
$refreshFilesButton.Text = "Refresh Files"
$refreshFilesButton.Font = $fontButton
$refreshFilesButton.Location = New-Object System.Drawing.Point(690, 53)
$refreshFilesButton.Size = New-Object System.Drawing.Size(115, 32)
$filesGroup.Controls.Add($refreshFilesButton)

$fileLabel = New-Object System.Windows.Forms.Label
$fileLabel.Text = "Transcribe:"
$fileLabel.Font = $fontSection
$fileLabel.Location = New-Object System.Drawing.Point(15, 92)
$fileLabel.Size = New-Object System.Drawing.Size(100, 25)
$filesGroup.Controls.Add($fileLabel)

$selectedFileRadioButton = New-Object System.Windows.Forms.RadioButton
$selectedFileRadioButton.Text = "Selected file"
$selectedFileRadioButton.Font = $fontMain
$selectedFileRadioButton.Location = New-Object System.Drawing.Point(120, 90)
$selectedFileRadioButton.Size = New-Object System.Drawing.Size(135, 27)
$selectedFileRadioButton.Checked = $true
$filesGroup.Controls.Add($selectedFileRadioButton)

$allFilesRadioButton = New-Object System.Windows.Forms.RadioButton
$allFilesRadioButton.Text = "All recognized files in source folder (0)"
$allFilesRadioButton.Font = $fontMain
$allFilesRadioButton.Location = New-Object System.Drawing.Point(265, 90)
$allFilesRadioButton.Size = New-Object System.Drawing.Size(390, 27)
$filesGroup.Controls.Add($allFilesRadioButton)

$fileCombo = New-Object System.Windows.Forms.ComboBox
$fileCombo.Font = $fontMain
$fileCombo.Location = New-Object System.Drawing.Point(15, 118)
$fileCombo.Size = New-Object System.Drawing.Size(650, 28)
$fileCombo.DropDownStyle = "DropDownList"
$filesGroup.Controls.Add($fileCombo)

$openInputButton = New-Object System.Windows.Forms.Button
$openInputButton.Text = "Open Source Folder"
$openInputButton.Font = $fontButton
$openInputButton.Location = New-Object System.Drawing.Point(675, 115)
$openInputButton.Size = New-Object System.Drawing.Size(135, 32)
$filesGroup.Controls.Add($openInputButton)

# -----------------------------
# Settings group controls
# -----------------------------

$outputModeLabel = New-Object System.Windows.Forms.Label
$outputModeLabel.Text = "Output mode:"
$outputModeLabel.Font = $fontSection
$outputModeLabel.Location = New-Object System.Drawing.Point(70, 30)
$outputModeLabel.Size = New-Object System.Drawing.Size(160, 25)
$settingsGroup.Controls.Add($outputModeLabel)

$outputModeCombo = New-Object System.Windows.Forms.ComboBox
$outputModeCombo.Font = $fontMain
$outputModeCombo.Location = New-Object System.Drawing.Point(70, 58)
$outputModeCombo.Size = New-Object System.Drawing.Size(375, 28)
$outputModeCombo.DropDownStyle = "DropDownList"
[void]$outputModeCombo.Items.Add("Default - Original file, WAV audio, TXT transcript")
[void]$outputModeCombo.Items.Add("Full - Original file, WAV audio, TXT, SRT, VTT, TSV, JSON")
$outputModeCombo.SelectedIndex = 0
$settingsGroup.Controls.Add($outputModeCombo)

$modelLabel = New-Object System.Windows.Forms.Label
$modelLabel.Text = "Transcription mode:"
$modelLabel.Font = $fontSection
$modelLabel.Location = New-Object System.Drawing.Point(485, 30)
$modelLabel.Size = New-Object System.Drawing.Size(230, 25)
$settingsGroup.Controls.Add($modelLabel)

$modelCombo = New-Object System.Windows.Forms.ComboBox
$modelCombo.Font = $fontMain
$modelCombo.Location = New-Object System.Drawing.Point(485, 58)
$modelCombo.Size = New-Object System.Drawing.Size(265, 28)
$modelCombo.DropDownStyle = "DropDownList"
[void]$modelCombo.Items.Add("Fast - recommended")
[void]$modelCombo.Items.Add("Accurate - slower, for difficult audio")
$modelCombo.SelectedIndex = 0
$settingsGroup.Controls.Add($modelCombo)

$languageLabel = New-Object System.Windows.Forms.Label
$languageLabel.Text = "Input Audio:"
$languageLabel.Font = $fontSection
$languageLabel.Location = New-Object System.Drawing.Point(70, 100)
$languageLabel.Size = New-Object System.Drawing.Size(130, 25)
$settingsGroup.Controls.Add($languageLabel)

$languageCombo = New-Object System.Windows.Forms.ComboBox
$languageCombo.Font = $fontMain
$languageCombo.Location = New-Object System.Drawing.Point(70, 125)
$languageCombo.Size = New-Object System.Drawing.Size(125, 28)
$languageCombo.DropDownStyle = "DropDownList"

foreach ($languageName in $LanguageOptions.Keys) {
    [void]$languageCombo.Items.Add($languageName)
}

$defaultLanguageName = Get-LanguageNameFromCode -LanguageCode $DefaultLanguage
$languageCombo.SelectedItem = $defaultLanguageName

if ($null -eq $languageCombo.SelectedItem -and $languageCombo.Items.Count -gt 0) {
    $languageCombo.SelectedIndex = 0
}

$settingsGroup.Controls.Add($languageCombo)

$outputTextLabel = New-Object System.Windows.Forms.Label
$outputTextLabel.Text = "Output Text:"
$outputTextLabel.Font = $fontSection
$outputTextLabel.Location = New-Object System.Drawing.Point(245, 100)
$outputTextLabel.Size = New-Object System.Drawing.Size(150, 25)
$settingsGroup.Controls.Add($outputTextLabel)

$outputTextCombo = New-Object System.Windows.Forms.ComboBox
$outputTextCombo.Font = $fontMain
$outputTextCombo.Location = New-Object System.Drawing.Point(245, 125)
$outputTextCombo.Size = New-Object System.Drawing.Size(200, 28)
$outputTextCombo.DropDownStyle = "DropDownList"

foreach ($outputTextName in $OutputTextOptions.Keys) {
    [void]$outputTextCombo.Items.Add($outputTextName)
}

$outputTextCombo.SelectedIndex = 0
$settingsGroup.Controls.Add($outputTextCombo)

# -----------------------------
# Action buttons
# -----------------------------

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Start Transcription"
$startButton.Font = $fontButtonBold
$startButton.Location = New-Object System.Drawing.Point(60, 460)
$startButton.Size = New-Object System.Drawing.Size(190, 42)
$startButton.BackColor = $colorStartGreen
$startButton.ForeColor = [System.Drawing.Color]::White
$startButton.FlatStyle = "Flat"
$form.Controls.Add($startButton)

$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Text = "Stop Transcription"
$stopButton.Font = $fontButtonBold
$stopButton.Location = New-Object System.Drawing.Point(260, 460)
$stopButton.Size = New-Object System.Drawing.Size(175, 42)
$stopButton.Enabled = $false
$form.Controls.Add($stopButton)

$openOutputButton = New-Object System.Windows.Forms.Button
$openOutputButton.Text = "Open Output Folder"
$openOutputButton.Font = $fontButton
$openOutputButton.Location = New-Object System.Drawing.Point(445, 465)
$openOutputButton.Size = New-Object System.Drawing.Size(175, 34)
$form.Controls.Add($openOutputButton)

$clearStatusButton = New-Object System.Windows.Forms.Button
$clearStatusButton.Text = "Clear Status Window"
$clearStatusButton.Font = $fontButton
$clearStatusButton.Location = New-Object System.Drawing.Point(650, 465)
$clearStatusButton.Size = New-Object System.Drawing.Size(150, 34)
$form.Controls.Add($clearStatusButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close MediaScribe"
$closeButton.Font = $fontButton
$closeButton.Location = New-Object System.Drawing.Point(350, 850)
$closeButton.Size = New-Object System.Drawing.Size(170, 34)
$closeButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom
$form.Controls.Add($closeButton)

# -----------------------------
# Status group controls
# -----------------------------

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Status: Ready"
$statusLabel.Font = $fontSection
$statusLabel.Location = New-Object System.Drawing.Point(15, 28)
$statusLabel.Size = New-Object System.Drawing.Size(790, 25)
$statusLabel.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Top `
    -bor [System.Windows.Forms.AnchorStyles]::Left `
    -bor [System.Windows.Forms.AnchorStyles]::Right
)
$statusGroup.Controls.Add($statusLabel)

$statusBox = New-Object System.Windows.Forms.TextBox
$statusBox.Location = New-Object System.Drawing.Point(15, 58)
$statusBox.Size = New-Object System.Drawing.Size(790, 235)
$statusBox.Anchor = (
    [System.Windows.Forms.AnchorStyles]::Top `
    -bor [System.Windows.Forms.AnchorStyles]::Bottom `
    -bor [System.Windows.Forms.AnchorStyles]::Left `
    -bor [System.Windows.Forms.AnchorStyles]::Right
)
$statusBox.Multiline = $true
$statusBox.ScrollBars = "Vertical"
$statusBox.ReadOnly = $true
$statusBox.Font = $fontStatus
$statusGroup.Controls.Add($statusBox)


# -----------------------------
# Apply GUI theme
# -----------------------------

# Main form text
$form.BackColor = $colorFormBackground
$form.ForeColor = $colorPrimaryText

$titleLabel.ForeColor = $colorPrimaryText
$subtitleLabel.ForeColor = $colorSecondaryText

# Group box surfaces and titles
foreach ($group in @(
    $filesGroup,
    $settingsGroup,
    $statusGroup
)) {
    $group.BackColor = $colorPanelBackground
    $group.ForeColor = $colorGroupText
}

# Normal labels inside the group boxes
foreach ($label in @(
    $sourceFolderLabel,
    $fileLabel,
    $outputModeLabel,
    $modelLabel,
    $languageLabel,
    $outputTextLabel
)) {
    $label.ForeColor = $colorPrimaryText
}

# File-mode choices
foreach ($radioButton in @(
    $selectedFileRadioButton,
    $allFilesRadioButton
)) {
    $radioButton.BackColor = $colorPanelBackground
    $radioButton.ForeColor = $colorPrimaryText
}

# Keep the current status emphasized with the accent color
$statusLabel.ForeColor = $colorGroupText

# Text entry and dropdown controls
foreach ($control in @(
    $sourceFolderTextBox,
    $fileCombo,
    $outputModeCombo,
    $modelCombo,
    $languageCombo,
    $outputTextCombo,
    $statusBox
)) {
    $control.BackColor = $colorInputBackground
    $control.ForeColor = $colorPrimaryText
}

# Neutral buttons
foreach ($button in @(
    $browseFolderButton,
    $refreshFilesButton,
    $openInputButton,
    $openOutputButton,
    $clearStatusButton,
    $closeButton
)) {
    $button.UseVisualStyleBackColor = $false
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.BackColor = $colorButtonBackground
    $button.ForeColor = $colorButtonText

    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = $colorButtonBorder
    $button.FlatAppearance.MouseOverBackColor = $colorButtonHover
    $button.FlatAppearance.MouseDownBackColor = $colorButtonDown
}

# Primary action button
$startButton.UseVisualStyleBackColor = $false
$startButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$startButton.BackColor = $colorStartGreen
$startButton.ForeColor = [System.Drawing.Color]::White

$startButton.FlatAppearance.BorderSize = 1
$startButton.FlatAppearance.BorderColor = $colorStartGreenDown
$startButton.FlatAppearance.MouseOverBackColor = $colorStartGreenHover
$startButton.FlatAppearance.MouseDownBackColor = $colorStartGreenDown

# Stop button is neutral while disabled and red only while active.
$stopButton.UseVisualStyleBackColor = $false
$stopButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$stopButton.BackColor = $colorButtonBackground
$stopButton.ForeColor = $colorButtonText
$stopButton.FlatAppearance.BorderSize = 1
$stopButton.FlatAppearance.BorderColor = $colorButtonBorder


# Keep the bottom Close button centered when the form width changes.
$form.Add_Resize({
    $closeButton.Left = [int](($form.ClientSize.Width - $closeButton.Width) / 2)
})

# -----------------------------
# Events
# -----------------------------

$script:IsRunning = $false
$script:StopRequested = $false
$script:StopRequestedAt = $null
$script:RunningProcess = $null
$script:CurrentLogFile = $null
$script:StopRequestFile = $null
$script:StateFile = $null
$script:LastLogLength = 0
$script:ForcedStopTimeoutSeconds = 20

function Stop-GuiBackendProcessTree {
    if ($null -eq $script:RunningProcess) {
        return
    }

    try {
        if (-not $script:RunningProcess.HasExited) {
            & taskkill.exe /PID $script:RunningProcess.Id /T /F 2>$null | Out-Null
        }
    } catch {
        try {
            $script:RunningProcess.Kill()
        } catch {
            # The process may already have exited.
        }
    }
}

function Move-GuiRecordedJobToAborted {
    if ([string]::IsNullOrWhiteSpace($script:StateFile) -or -not (Test-Path -LiteralPath $script:StateFile)) {
        return
    }

    try {
        $state = Get-Content -LiteralPath $script:StateFile -Raw | ConvertFrom-Json
        $jobDir = [string]$state.JobDir

        if ([string]::IsNullOrWhiteSpace($jobDir) -or -not (Test-Path -LiteralPath $jobDir -PathType Container)) {
            return
        }

        $currentName = Split-Path -Leaf $jobDir
        if ($currentName.StartsWith("ABORTED_", [System.StringComparison]::OrdinalIgnoreCase)) {
            return
        }

        $parentFolder = Split-Path -Parent $jobDir
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $abortedPath = Join-Path $parentFolder ("ABORTED_{0}_{1}" -f $currentName, $stamp)
        $counter = 1

        while (Test-Path -LiteralPath $abortedPath) {
            $abortedPath = Join-Path $parentFolder ("ABORTED_{0}_{1}_{2}" -f $currentName, $stamp, $counter)
            $counter++
        }

        Move-Item -LiteralPath $jobDir -Destination $abortedPath -ErrorAction Stop
        Add-Status "Incomplete job folder: $abortedPath"
    } catch {
        Add-Status "The incomplete job folder could not be renamed automatically after forced shutdown."
    }
}

function Remove-RunControlFiles {
    foreach ($path in @($script:StopRequestFile, $script:StateFile)) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath ("$path.tmp") -Force -ErrorAction SilentlyContinue
        }
    }

    $script:StopRequestFile = $null
    $script:StateFile = $null
    $script:StopRequestedAt = $null
}

$logTimer = New-Object System.Windows.Forms.Timer
$logTimer.Interval = 1000

$logTimer.Add_Tick({
    if ($script:CurrentLogFile -and (Test-Path -LiteralPath $script:CurrentLogFile)) {
        try {
            $fileInfo = Get-Item -LiteralPath $script:CurrentLogFile

            if ($fileInfo.Length -gt $script:LastLogLength) {
                $stream = [System.IO.File]::Open(
                    $script:CurrentLogFile,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::ReadWrite
                )

                try {
                    $stream.Seek($script:LastLogLength, [System.IO.SeekOrigin]::Begin) | Out-Null
                    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
                    $reader = New-Object System.IO.StreamReader($stream, $utf8NoBom, $true)
                    $newText = $reader.ReadToEnd()

                    if (-not [string]::IsNullOrWhiteSpace($newText)) {
                        $statusBox.AppendText($newText)
                        $statusBox.SelectionStart = $statusBox.Text.Length
                        $statusBox.ScrollToCaret()
                    }

                    $script:LastLogLength = $fileInfo.Length
                } finally {
                    $stream.Close()
                }
            }
        } catch {
            # Ignore temporary read/lock timing errors.
        }
    }

    if ($script:StopRequested -and $null -ne $script:StopRequestedAt -and $null -ne $script:RunningProcess) {
        try {
            if (-not $script:RunningProcess.HasExited) {
                $elapsed = (Get-Date) - $script:StopRequestedAt
                if ($elapsed.TotalSeconds -ge $script:ForcedStopTimeoutSeconds) {
                    Add-Status "Stop is taking longer than expected. Forcing the transcription process to close..."
                    Stop-GuiBackendProcessTree
                    Start-Sleep -Milliseconds 500
                    Move-GuiRecordedJobToAborted
                    $script:StopRequestedAt = $null
                }
            }
        } catch {
            # The normal exit handler below will finish GUI cleanup.
        }
    }

    if ($null -ne $script:RunningProcess) {
    try {
        if ($script:RunningProcess.HasExited) {
            $exitCode = $script:RunningProcess.ExitCode
            $wasStopRequested = $script:StopRequested

            $logTimer.Stop()

            Add-Status ""
            Add-Status "MediaScribe finished with exit code $exitCode."

            # Re-enable the GUI controls.
            Set-RunningState -IsRunning $false

            # Rescan the source folder so moved or removed files disappear
            # from the Selected File dropdown.
            Update-FileList -FolderPath $script:SourceFolder

            # Set the final status after the functions above, because both
            # can change the status label.
            if ($exitCode -eq 0) {
                $statusLabel.Text = "Status: Complete"
            } elseif ($exitCode -eq 2 -or $wasStopRequested) {
                $statusLabel.Text = "Status: Stopped"
            } else {
                $statusLabel.Text = "Status: Finished with errors"
            }

            Remove-RunControlFiles
            $script:RunningProcess.Dispose()
            $script:RunningProcess = $null
        }
    } catch {
        $logTimer.Stop()
        Add-Status ""
        Add-Status "MediaScribe process ended, but status could not be read."
        Set-RunningState -IsRunning $false
        Remove-RunControlFiles
        $script:RunningProcess = $null
    }
}
})

$selectedFileRadioButton.Add_CheckedChanged({
    Update-FileSelectionMode
})

$allFilesRadioButton.Add_CheckedChanged({
    Update-FileSelectionMode
})

$browseFolderButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choose a folder that contains audio or video files"
    $dialog.SelectedPath = $script:SourceFolder
    $dialog.ShowNewFolderButton = $false

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Update-FileList -FolderPath $dialog.SelectedPath
        Add-Status "Source folder changed: $($dialog.SelectedPath)"
    }
})

$refreshFilesButton.Add_Click({
    Update-FileList -FolderPath $script:SourceFolder
    Add-Status "File list refreshed."
})

$openInputButton.Add_Click({
    if (Test-Path -LiteralPath $script:SourceFolder -PathType Container) {
        Start-Process explorer.exe $script:SourceFolder
    }
})

$openOutputButton.Add_Click({
    Start-Process explorer.exe $OutputDir
})

$clearStatusButton.Add_Click({
    $statusBox.Clear()
})

$closeButton.Add_Click({
    $form.Close()
})

$stopButton.Add_Click({
    if (-not $script:IsRunning -or $null -eq $script:RunningProcess) {
        return
    }

    $message = "MediaScribe is still working on this file.`n`nIf you stop now, MediaScribe will not create a finished transcript.`n`nDo you want to stop transcription?"
    $choice = [System.Windows.Forms.MessageBox]::Show(
        $message,
        "Stop Transcription",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning,
        [System.Windows.Forms.MessageBoxDefaultButton]::Button2
    )

    if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
        [System.IO.File]::WriteAllText($script:StopRequestFile, "stop", $utf8NoBom)
        $script:StopRequested = $true
        $script:StopRequestedAt = Get-Date
        $statusLabel.Text = "Status: Stopping"
        Add-Status ""
        if ($allFilesRadioButton.Checked) {
            Add-Status "Stop requested. MediaScribe is stopping the active transcription and cancelling the remaining batch."
        } else {
            Add-Status "Stop requested. MediaScribe is stopping the active transcription."
        }
        Update-StopButtonAppearance
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "MediaScribe could not create the stop request.`n`n$($_.Exception.Message)",
            "Stop Transcription",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$startButton.Add_Click({
    if (-not (Test-Path -LiteralPath $TranscribeScript)) {
        [System.Windows.Forms.MessageBox]::Show(
            "transcribe.ps1 was not found:`n$TranscribeScript",
            "MediaScribe",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    $batchMode = $allFilesRadioButton.Checked
    $selectedFile = $null
    $batchFiles = @()

    if ($batchMode) {
        if ([string]::IsNullOrWhiteSpace($script:SourceFolder) -or
            -not (Test-Path -LiteralPath $script:SourceFolder -PathType Container)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Choose a valid source folder first.",
                "MediaScribe",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        $batchFiles = @(Get-MediaFilesFromFolder -FolderPath $script:SourceFolder)

        if ($batchFiles.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "No recognized audio or video files were found in the source folder.",
                "MediaScribe",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }
    } else {
        $selectedFile = Get-SelectedMediaFile

        if ([string]::IsNullOrWhiteSpace($selectedFile) -or
            -not (Test-Path -LiteralPath $selectedFile -PathType Leaf)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Choose a valid audio or video file from the list first.",
                "MediaScribe",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }
    }

    $selectedOutputMode = if ($outputModeCombo.SelectedIndex -eq 1) { "full" } else { "default" }
    $selectedModel = if ($modelCombo.SelectedIndex -eq 1) { "large" } else { $DefaultModel }

    $selectedLanguageName = [string]$languageCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($selectedLanguageName)) {
        $selectedLanguageName = "English"
    }

    $selectedLanguage = $LanguageOptions[$selectedLanguageName]
    if ([string]::IsNullOrWhiteSpace($selectedLanguage)) {
        $selectedLanguage = "en"
    }

    $selectedOutputTextName = [string]$outputTextCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($selectedOutputTextName)) {
        $selectedOutputTextName = "Same as input / detected"
    }

    $selectedOutputText = $OutputTextOptions[$selectedOutputTextName]
    if ([string]::IsNullOrWhiteSpace($selectedOutputText)) {
        $selectedOutputText = "same"
    }

    # Whisper translates to English only. English input + English output is handled as normal transcription.
    $selectedTask = "transcribe"
    if ($selectedOutputText -eq "english" -and $selectedLanguage -ne "en") {
        $selectedTask = "translate"
    }

    $statusBox.Clear()

    if ($batchMode) {
        Add-Status "MediaScribe GUI batch transcription started."
        Add-Status "Batch source path: $($script:SourceFolder)"
        Add-Status "Recognized files: $($batchFiles.Count)"
    } else {
        Add-Status "MediaScribe GUI started."
        Add-Status "Selected file: $selectedFile"
    }

    Add-Status "Output mode: $selectedOutputMode"
    Add-Status "Whisper model: $selectedModel"
    Add-Status "Input audio: $selectedLanguageName"
    Add-Status "Output text: $selectedOutputTextName"
    Add-Status "Whisper task: $selectedTask"
    Add-Status ""

    Set-RunningState -IsRunning $true

    $runId = [guid]::NewGuid().ToString()
    $script:CurrentLogFile = Join-Path $env:TEMP ("MediaScribe-GUI-" + $runId + ".log")
    $script:StopRequestFile = Join-Path $env:TEMP ("MediaScribe-" + $runId + ".stop")
    $script:StateFile = Join-Path $env:TEMP ("MediaScribe-" + $runId + ".state.json")
    $script:StopRequested = $false
    $script:StopRequestedAt = $null
    $script:LastLogLength = 0

    Remove-Item -LiteralPath $script:StopRequestFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $script:StateFile -Force -ErrorAction SilentlyContinue

    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::WriteAllText($script:CurrentLogFile, "", $utf8NoBom)

    $sourceArguments = if ($batchMode) {
        @(
            "-BatchSourcePath", "`"$($script:SourceFolder)`""
        )
    } else {
        @(
            "-InputFile", "`"$selectedFile`""
        )
    }

    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$TranscribeScript`""
    ) + $sourceArguments + @(
        "-OutputMode", $selectedOutputMode,
        "-Model", $selectedModel,
        "-Language", $selectedLanguage,
        "-Task", $selectedTask,
        "-StopRequestFile", "`"$($script:StopRequestFile)`"",
        "-StateFile", "`"$($script:StateFile)`""
    )

    $arguments = $arguments -join " "

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = $arguments
    $psi.WorkingDirectory = $ScriptDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
        $psi.StandardOutputEncoding = $utf8NoBom
        $psi.StandardErrorEncoding = $utf8NoBom

        $psi.EnvironmentVariables["PYTHONIOENCODING"] = "utf-8"
        $psi.EnvironmentVariables["PYTHONUTF8"] = "1"
        $psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1"
    } catch {
        # Older hosts may not support every encoding property. Continue with defaults.
    }

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    try {
        $script:RunningProcess = $process

        [void]$process.Start()

        # Use background stream readers that append safely to the log file.
        $outputReader = {
            param($proc, $logPath)

            $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false

            while (-not $proc.StandardOutput.EndOfStream) {
                $line = $proc.StandardOutput.ReadLine()
                [System.IO.File]::AppendAllText($logPath, ($line + [Environment]::NewLine), $utf8NoBom)
            }
        }

        $errorReader = {
            param($proc, $logPath)

            $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false

            while (-not $proc.StandardError.EndOfStream) {
                $line = $proc.StandardError.ReadLine()
                [System.IO.File]::AppendAllText($logPath, ($line + [Environment]::NewLine), $utf8NoBom)
            }
        }

        $script:OutputPowerShell = [powershell]::Create()
        $script:OutputPowerShell.AddScript($outputReader).AddArgument($process).AddArgument($script:CurrentLogFile) | Out-Null
        $script:OutputHandle = $script:OutputPowerShell.BeginInvoke()

        $script:ErrorPowerShell = [powershell]::Create()
        $script:ErrorPowerShell.AddScript($errorReader).AddArgument($process).AddArgument($script:CurrentLogFile) | Out-Null
        $script:ErrorHandle = $script:ErrorPowerShell.BeginInvoke()

        $logTimer.Start()
    } catch {
        Add-Status "Failed to start transcription."
        Add-Status $_.Exception.Message
        Set-RunningState -IsRunning $false
        Remove-RunControlFiles
        $script:RunningProcess = $null
        $logTimer.Stop()
    }
})

$form.Add_FormClosing({
    if ($null -ne $script:RunningProcess -and -not $script:RunningProcess.HasExited) {
        [System.Windows.Forms.MessageBox]::Show(
            "MediaScribe is still transcribing.`n`nUse Stop Transcription first, or wait for the transcription to finish before closing MediaScribe.",
            "Transcription Still Running",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null

        $_.Cancel = $true
        return
    }

    try {
        $logTimer.Stop()
    } catch {
        # Ignore timer shutdown errors.
    }
})

Add-Status "MediaScribe GUI ready."
Add-Status "Input folder: $InputDir"
Add-Status "Output folder: $OutputDir"

Update-FileList -FolderPath $script:SourceFolder
Update-StopButtonAppearance

try {
    [void]$form.ShowDialog()
} finally {
    Release-MediaScribeSingleInstanceMutex
}