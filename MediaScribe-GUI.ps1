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
    $languageTextBox.Enabled = -not $IsRunning
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
$form.Size = New-Object System.Drawing.Size(860, 775)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(820, 680)
$form.WindowState = "Normal"
$form.ShowInTaskbar = $true

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "MediaScribe"
$titleLabel.Font = $fontHeader
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$titleLabel.Size = New-Object System.Drawing.Size(800, 42)
$form.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Create transcripts and optional caption files from audio/video files."
$subtitleLabel.Font = $fontSubtitle
$subtitleLabel.Location = New-Object System.Drawing.Point(22, 58)
$subtitleLabel.Size = New-Object System.Drawing.Size(800, 28)
$form.Controls.Add($subtitleLabel)

# -----------------------------
# Source folder and selected file
# -----------------------------

$sourceFolderLabel = New-Object System.Windows.Forms.Label
$sourceFolderLabel.Text = "Source folder:"
$sourceFolderLabel.Font = $fontSection
$sourceFolderLabel.Location = New-Object System.Drawing.Point(25, 105)
$sourceFolderLabel.Size = New-Object System.Drawing.Size(160, 25)
$form.Controls.Add($sourceFolderLabel)

$sourceFolderTextBox = New-Object System.Windows.Forms.TextBox
$sourceFolderTextBox.Font = $fontMain
$sourceFolderTextBox.Location = New-Object System.Drawing.Point(25, 132)
$sourceFolderTextBox.Size = New-Object System.Drawing.Size(520, 27)
$sourceFolderTextBox.ReadOnly = $true
$form.Controls.Add($sourceFolderTextBox)

$browseFolderButton = New-Object System.Windows.Forms.Button
$browseFolderButton.Text = "Browse Folder..."
$browseFolderButton.Font = $fontButton
$browseFolderButton.Location = New-Object System.Drawing.Point(555, 130)
$browseFolderButton.Size = New-Object System.Drawing.Size(135, 32)
$form.Controls.Add($browseFolderButton)

$refreshFilesButton = New-Object System.Windows.Forms.Button
$refreshFilesButton.Text = "Refresh Files"
$refreshFilesButton.Font = $fontButton
$refreshFilesButton.Location = New-Object System.Drawing.Point(700, 130)
$refreshFilesButton.Size = New-Object System.Drawing.Size(125, 32)
$form.Controls.Add($refreshFilesButton)

$fileLabel = New-Object System.Windows.Forms.Label
$fileLabel.Text = "Selected file:"
$fileLabel.Font = $fontSection
$fileLabel.Location = New-Object System.Drawing.Point(25, 174)
$fileLabel.Size = New-Object System.Drawing.Size(160, 25)
$form.Controls.Add($fileLabel)

$fileCombo = New-Object System.Windows.Forms.ComboBox
$fileCombo.Font = $fontMain
$fileCombo.Location = New-Object System.Drawing.Point(25, 202)
$fileCombo.Size = New-Object System.Drawing.Size(665, 28)
$fileCombo.DropDownStyle = "DropDownList"
$form.Controls.Add($fileCombo)

$openInputButton = New-Object System.Windows.Forms.Button
$openInputButton.Text = "Open Folder"
$openInputButton.Font = $fontButton
$openInputButton.Location = New-Object System.Drawing.Point(700, 200)
$openInputButton.Size = New-Object System.Drawing.Size(125, 32)
$form.Controls.Add($openInputButton)

# -----------------------------
# Output mode
# -----------------------------

$outputModeLabel = New-Object System.Windows.Forms.Label
$outputModeLabel.Text = "Output mode:"
$outputModeLabel.Font = $fontSection
$outputModeLabel.Location = New-Object System.Drawing.Point(25, 255)
$outputModeLabel.Size = New-Object System.Drawing.Size(160, 25)
$form.Controls.Add($outputModeLabel)

$outputModeCombo = New-Object System.Windows.Forms.ComboBox
$outputModeCombo.Font = $fontMain
$outputModeCombo.Location = New-Object System.Drawing.Point(25, 283)
$outputModeCombo.Size = New-Object System.Drawing.Size(280, 28)
$outputModeCombo.DropDownStyle = "DropDownList"
[void]$outputModeCombo.Items.Add("Default - TXT only")
[void]$outputModeCombo.Items.Add("Full - TXT, SRT, VTT, TSV, JSON")
$outputModeCombo.SelectedIndex = 0
$form.Controls.Add($outputModeCombo)

# -----------------------------
# Model / transcription mode
# -----------------------------

$modelLabel = New-Object System.Windows.Forms.Label
$modelLabel.Text = "Transcription mode:"
$modelLabel.Font = $fontSection
$modelLabel.Location = New-Object System.Drawing.Point(335, 255)
$modelLabel.Size = New-Object System.Drawing.Size(210, 25)
$form.Controls.Add($modelLabel)

$modelCombo = New-Object System.Windows.Forms.ComboBox
$modelCombo.Font = $fontMain
$modelCombo.Location = New-Object System.Drawing.Point(335, 283)
$modelCombo.Size = New-Object System.Drawing.Size(270, 28)
$modelCombo.DropDownStyle = "DropDownList"
[void]$modelCombo.Items.Add("Fast - $DefaultModel")
[void]$modelCombo.Items.Add("Accurate - large")
$modelCombo.SelectedIndex = 0
$form.Controls.Add($modelCombo)

# -----------------------------
# Language
# -----------------------------

$languageLabel = New-Object System.Windows.Forms.Label
$languageLabel.Text = "Language:"
$languageLabel.Font = $fontSection
$languageLabel.Location = New-Object System.Drawing.Point(635, 255)
$languageLabel.Size = New-Object System.Drawing.Size(140, 25)
$form.Controls.Add($languageLabel)

$languageTextBox = New-Object System.Windows.Forms.TextBox
$languageTextBox.Font = $fontMain
$languageTextBox.Location = New-Object System.Drawing.Point(635, 283)
$languageTextBox.Size = New-Object System.Drawing.Size(190, 27)
$languageTextBox.Text = $DefaultLanguage
$form.Controls.Add($languageTextBox)

# -----------------------------
# Buttons
# -----------------------------

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Start Transcription"
$startButton.Font = $fontButtonBold
$startButton.Location = New-Object System.Drawing.Point(25, 338)
$startButton.Size = New-Object System.Drawing.Size(190, 42)
$form.Controls.Add($startButton)

$openOutputButton = New-Object System.Windows.Forms.Button
$openOutputButton.Text = "Open Output Folder"
$openOutputButton.Font = $fontButton
$openOutputButton.Location = New-Object System.Drawing.Point(235, 344)
$openOutputButton.Size = New-Object System.Drawing.Size(175, 34)
$form.Controls.Add($openOutputButton)

$clearStatusButton = New-Object System.Windows.Forms.Button
$clearStatusButton.Text = "Clear Status"
$clearStatusButton.Font = $fontButton
$clearStatusButton.Location = New-Object System.Drawing.Point(425, 344)
$clearStatusButton.Size = New-Object System.Drawing.Size(130, 34)
$form.Controls.Add($clearStatusButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close MediaScribe"
$closeButton.Font = $fontButton
$closeButton.Location = New-Object System.Drawing.Point(350, 675)
$closeButton.Size = New-Object System.Drawing.Size(155, 34)
$form.Controls.Add($closeButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Status: Ready"
$statusLabel.Font = $fontSection
$statusLabel.Location = New-Object System.Drawing.Point(25, 405)
$statusLabel.Size = New-Object System.Drawing.Size(800, 25)
$form.Controls.Add($statusLabel)

# -----------------------------
# Status output
# -----------------------------

$statusBox = New-Object System.Windows.Forms.TextBox
$statusBox.Location = New-Object System.Drawing.Point(25, 435)
$statusBox.Size = New-Object System.Drawing.Size(800, 235)
$statusBox.Multiline = $true
$statusBox.ScrollBars = "Vertical"
$statusBox.ReadOnly = $true
$statusBox.Font = $fontStatus
$form.Controls.Add($statusBox)

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
    $selectedLanguage = $languageTextBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($selectedLanguage)) {
        $selectedLanguage = $DefaultLanguage
    }

    $statusBox.Clear()
    Add-Status "MediaScribe GUI started."
    Add-Status "Selected file: $selectedFile"
    Add-Status "Output mode: $selectedOutputMode"
    Add-Status "Whisper model: $selectedModel"
    Add-Status "Language: $selectedLanguage"
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