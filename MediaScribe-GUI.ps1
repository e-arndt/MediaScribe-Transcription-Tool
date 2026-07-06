# =====================================================
# MediaScribe-GUI.ps1
# Phase 2 GUI wrapper for transcribe.ps1
# =====================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

$colorFormBackground = [System.Drawing.Color]::FromArgb(218, 229, 231)
$colorPanelBackground = [System.Drawing.Color]::FromArgb(245, 248, 248)
$colorGroupText = [System.Drawing.Color]::FromArgb(0, 80, 95)
$colorStartGreen = [System.Drawing.Color]::FromArgb(0, 128, 64)

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
    "Spanish"     = "es"
    "French"      = "fr"
    "German"      = "de"
    "Italian"     = "it"
    "Portuguese"  = "pt"
    "Japanese"    = "ja"
    "Korean"      = "ko"
    "Chinese"     = "zh"
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

function Refresh-FileList {
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
    $mediaFiles = Get-MediaFilesFromFolder -FolderPath $FolderPath

    foreach ($mediaFile in $mediaFiles) {
        [void]$fileCombo.Items.Add($mediaFile.Name)
    }

    if ($fileCombo.Items.Count -gt 0) {
        $fileCombo.SelectedIndex = 0
        $statusLabel.Text = "Status: Ready"
    } else {
        $statusLabel.Text = "Status: No recognized media files found"
    }
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

function Add-Status {
    param([string]$Text)

    if ($null -eq $Text) {
        return
    }

    $statusBox.AppendText($Text + [Environment]::NewLine)
    $statusBox.SelectionStart = $statusBox.Text.Length
    $statusBox.ScrollToCaret()
}

function Set-RunningState {
    param([bool]$IsRunning)

    $browseFolderButton.Enabled = -not $IsRunning
    $refreshFilesButton.Enabled = -not $IsRunning
    $fileCombo.Enabled = -not $IsRunning
    $startButton.Enabled = -not $IsRunning
    $outputModeCombo.Enabled = -not $IsRunning
    $modelCombo.Enabled = -not $IsRunning
    $languageCombo.Enabled = -not $IsRunning
    $openInputButton.Enabled = -not $IsRunning
    $openOutputButton.Enabled = -not $IsRunning
    $clearStatusButton.Enabled = -not $IsRunning

    if ($IsRunning) {
        $statusLabel.Text = "Status: Running"
    } else {
        $statusLabel.Text = "Status: Ready"
    }
}

# -----------------------------
# Form
# -----------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "MediaScribe"
$form.Size = New-Object System.Drawing.Size(880, 800)
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
$settingsGroup.Location = New-Object System.Drawing.Point(20, 265)
$settingsGroup.Size = New-Object System.Drawing.Size(825, 115)
$settingsGroup.BackColor = $colorPanelBackground
$settingsGroup.ForeColor = $colorGroupText
$form.Controls.Add($settingsGroup)

$statusGroup = New-Object System.Windows.Forms.GroupBox
$statusGroup.Text = "Status"
$statusGroup.Font = $fontSection
$statusGroup.Location = New-Object System.Drawing.Point(20, 455)
$statusGroup.Size = New-Object System.Drawing.Size(825, 250)
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
$fileLabel.Text = "Selected file:"
$fileLabel.Font = $fontSection
$fileLabel.Location = New-Object System.Drawing.Point(15, 92)
$fileLabel.Size = New-Object System.Drawing.Size(160, 25)
$filesGroup.Controls.Add($fileLabel)

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
$outputModeLabel.Location = New-Object System.Drawing.Point(15, 30)
$outputModeLabel.Size = New-Object System.Drawing.Size(160, 25)
$settingsGroup.Controls.Add($outputModeLabel)

$outputModeCombo = New-Object System.Windows.Forms.ComboBox
$outputModeCombo.Font = $fontMain
$outputModeCombo.Location = New-Object System.Drawing.Point(15, 58)
$outputModeCombo.Size = New-Object System.Drawing.Size(280, 28)
$outputModeCombo.DropDownStyle = "DropDownList"
[void]$outputModeCombo.Items.Add("Default - TXT only")
[void]$outputModeCombo.Items.Add("Full - TXT, SRT, VTT, TSV, JSON")
$outputModeCombo.SelectedIndex = 0
$settingsGroup.Controls.Add($outputModeCombo)

$modelLabel = New-Object System.Windows.Forms.Label
$modelLabel.Text = "Transcription mode:"
$modelLabel.Font = $fontSection
$modelLabel.Location = New-Object System.Drawing.Point(325, 30)
$modelLabel.Size = New-Object System.Drawing.Size(210, 25)
$settingsGroup.Controls.Add($modelLabel)

$modelCombo = New-Object System.Windows.Forms.ComboBox
$modelCombo.Font = $fontMain
$modelCombo.Location = New-Object System.Drawing.Point(325, 58)
$modelCombo.Size = New-Object System.Drawing.Size(270, 28)
$modelCombo.DropDownStyle = "DropDownList"
[void]$modelCombo.Items.Add("Fast - $DefaultModel")
[void]$modelCombo.Items.Add("Accurate - large")
$modelCombo.SelectedIndex = 0
$settingsGroup.Controls.Add($modelCombo)

$languageLabel = New-Object System.Windows.Forms.Label
$languageLabel.Text = "Language:"
$languageLabel.Font = $fontSection
$languageLabel.Location = New-Object System.Drawing.Point(625, 30)
$languageLabel.Size = New-Object System.Drawing.Size(140, 25)
$settingsGroup.Controls.Add($languageLabel)

$languageCombo = New-Object System.Windows.Forms.ComboBox
$languageCombo.Font = $fontMain
$languageCombo.Location = New-Object System.Drawing.Point(625, 58)
$languageCombo.Size = New-Object System.Drawing.Size(180, 28)
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

# -----------------------------
# Action buttons
# -----------------------------

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Start Transcription"
$startButton.Font = $fontButtonBold
$startButton.Location = New-Object System.Drawing.Point(60, 390)
$startButton.Size = New-Object System.Drawing.Size(190, 42)
$startButton.BackColor = $colorStartGreen
$startButton.ForeColor = [System.Drawing.Color]::White
$startButton.FlatStyle = "Flat"
$form.Controls.Add($startButton)

$openOutputButton = New-Object System.Windows.Forms.Button
$openOutputButton.Text = "Open Output Folder"
$openOutputButton.Font = $fontButton
$openOutputButton.Location = New-Object System.Drawing.Point(350, 395)
$openOutputButton.Size = New-Object System.Drawing.Size(175, 34)
$form.Controls.Add($openOutputButton)

$clearStatusButton = New-Object System.Windows.Forms.Button
$clearStatusButton.Text = "Clear Status Window"
$clearStatusButton.Font = $fontButton
$clearStatusButton.Location = New-Object System.Drawing.Point(650, 395)
$clearStatusButton.Size = New-Object System.Drawing.Size(150, 34)
$form.Controls.Add($clearStatusButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close MediaScribe"
$closeButton.Font = $fontButton
$closeButton.Location = New-Object System.Drawing.Point(350, 715)
$closeButton.Size = New-Object System.Drawing.Size(170, 34)
$form.Controls.Add($closeButton)

# -----------------------------
# Status group controls
# -----------------------------

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Status: Ready"
$statusLabel.Font = $fontSection
$statusLabel.Location = New-Object System.Drawing.Point(15, 28)
$statusLabel.Size = New-Object System.Drawing.Size(790, 25)
$statusGroup.Controls.Add($statusLabel)

$statusBox = New-Object System.Windows.Forms.TextBox
$statusBox.Location = New-Object System.Drawing.Point(15, 58)
$statusBox.Size = New-Object System.Drawing.Size(790, 175)
$statusBox.Multiline = $true
$statusBox.ScrollBars = "Vertical"
$statusBox.ReadOnly = $true
$statusBox.Font = $fontStatus
$statusGroup.Controls.Add($statusBox)

# -----------------------------
# Events
# -----------------------------

$script:RunningProcess = $null
$script:CurrentLogFile = $null
$script:LastLogLength = 0

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
                    $reader = New-Object System.IO.StreamReader($stream)
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

    if ($null -ne $script:RunningProcess) {
        try {
            if ($script:RunningProcess.HasExited) {
                $exitCode = $script:RunningProcess.ExitCode

                $logTimer.Stop()

                Add-Status ""
                Add-Status "MediaScribe finished with exit code $exitCode."

                if ($exitCode -eq 0) {
                    $statusLabel.Text = "Status: Complete"
                } else {
                    $statusLabel.Text = "Status: Finished with errors"
                }

                Set-RunningState -IsRunning $false
                $script:RunningProcess.Dispose()
                $script:RunningProcess = $null
            }
        } catch {
            $logTimer.Stop()
            Add-Status ""
            Add-Status "MediaScribe process ended, but status could not be read."
            Set-RunningState -IsRunning $false
            $script:RunningProcess = $null
        }
    }
})

$browseFolderButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Choose a folder that contains audio or video files"
    $dialog.SelectedPath = $script:SourceFolder
    $dialog.ShowNewFolderButton = $false

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Refresh-FileList -FolderPath $dialog.SelectedPath
        Add-Status "Source folder changed: $($dialog.SelectedPath)"
    }
})

$refreshFilesButton.Add_Click({
    Refresh-FileList -FolderPath $script:SourceFolder
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

    $selectedFile = Get-SelectedMediaFile

    if ([string]::IsNullOrWhiteSpace($selectedFile) -or -not (Test-Path -LiteralPath $selectedFile)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Choose a valid audio or video file from the list first.",
            "MediaScribe",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
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

    $statusBox.Clear()
    Add-Status "MediaScribe GUI started."
    Add-Status "Selected file: $selectedFile"
    Add-Status "Output mode: $selectedOutputMode"
    Add-Status "Whisper model: $selectedModel"
    Add-Status "Language: $selectedLanguageName"
    Add-Status ""

    Set-RunningState -IsRunning $true

    $script:CurrentLogFile = Join-Path $env:TEMP ("MediaScribe-GUI-" + [guid]::NewGuid().ToString() + ".log")
    $script:LastLogLength = 0

    New-Item -ItemType File -Path $script:CurrentLogFile -Force | Out-Null

    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$TranscribeScript`"",
        "-InputFile", "`"$selectedFile`"",
        "-OutputMode", $selectedOutputMode,
        "-Model", $selectedModel,
        "-Language", $selectedLanguage
    ) -join " "

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = $arguments
    $psi.WorkingDirectory = $ScriptDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    try {
        $script:RunningProcess = $process

        [void]$process.Start()

        # Use background stream readers that append safely to the log file.
        $outputReader = {
            param($proc, $logPath)

            while (-not $proc.StandardOutput.EndOfStream) {
                $line = $proc.StandardOutput.ReadLine()
                Add-Content -LiteralPath $logPath -Value $line
            }
        }

        $errorReader = {
            param($proc, $logPath)

            while (-not $proc.StandardError.EndOfStream) {
                $line = $proc.StandardError.ReadLine()
                Add-Content -LiteralPath $logPath -Value $line
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
        $script:RunningProcess = $null
        $logTimer.Stop()
    }
})

$form.Add_FormClosing({
    if ($null -ne $script:RunningProcess -and -not $script:RunningProcess.HasExited) {
        [System.Windows.Forms.MessageBox]::Show(
            "MediaScribe is still transcribing.`n`nPlease wait for the transcription to finish before closing MediaScribe.",
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

Refresh-FileList -FolderPath $script:SourceFolder

[void]$form.ShowDialog()