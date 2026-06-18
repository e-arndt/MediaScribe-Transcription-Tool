# =====================================================
# MediaScribe-GUI.ps1
# Phase 1 GUI wrapper for transcribe.ps1
# =====================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

function Quote-Argument {
    param([string]$Value)

    if ($null -eq $Value) {
        return '""'
    }

    return '"' + ($Value -replace '"', '\"') + '"'
}

function Append-Status {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return
    }

    $statusBox.AppendText($Text + [Environment]::NewLine)
    $statusBox.SelectionStart = $statusBox.Text.Length
    $statusBox.ScrollToCaret()
}

function Set-RunningState {
    param([bool]$IsRunning)

    $browseButton.Enabled = -not $IsRunning
    $startButton.Enabled = -not $IsRunning
    $outputModeCombo.Enabled = -not $IsRunning
    $modelCombo.Enabled = -not $IsRunning
    $languageTextBox.Enabled = -not $IsRunning
    $openInputButton.Enabled = -not $IsRunning
    $openOutputButton.Enabled = -not $IsRunning

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
$form.Size = New-Object System.Drawing.Size(820, 620)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(760, 560)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "MediaScribe"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$titleLabel.Size = New-Object System.Drawing.Size(760, 35)
$form.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Create transcripts and optional caption files from audio/video files."
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$subtitleLabel.Location = New-Object System.Drawing.Point(22, 52)
$subtitleLabel.Size = New-Object System.Drawing.Size(760, 25)
$form.Controls.Add($subtitleLabel)

# -----------------------------
# Selected file
# -----------------------------

$fileLabel = New-Object System.Windows.Forms.Label
$fileLabel.Text = "Selected file:"
$fileLabel.Location = New-Object System.Drawing.Point(25, 95)
$fileLabel.Size = New-Object System.Drawing.Size(120, 22)
$form.Controls.Add($fileLabel)

$fileTextBox = New-Object System.Windows.Forms.TextBox
$fileTextBox.Location = New-Object System.Drawing.Point(25, 120)
$fileTextBox.Size = New-Object System.Drawing.Size(630, 25)
$fileTextBox.ReadOnly = $true
$form.Controls.Add($fileTextBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = "Browse..."
$browseButton.Location = New-Object System.Drawing.Point(670, 118)
$browseButton.Size = New-Object System.Drawing.Size(110, 28)
$form.Controls.Add($browseButton)

# -----------------------------
# Output mode
# -----------------------------

$outputModeLabel = New-Object System.Windows.Forms.Label
$outputModeLabel.Text = "Output mode:"
$outputModeLabel.Location = New-Object System.Drawing.Point(25, 170)
$outputModeLabel.Size = New-Object System.Drawing.Size(140, 22)
$form.Controls.Add($outputModeLabel)

$outputModeCombo = New-Object System.Windows.Forms.ComboBox
$outputModeCombo.Location = New-Object System.Drawing.Point(25, 195)
$outputModeCombo.Size = New-Object System.Drawing.Size(260, 25)
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
$modelLabel.Location = New-Object System.Drawing.Point(315, 170)
$modelLabel.Size = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($modelLabel)

$modelCombo = New-Object System.Windows.Forms.ComboBox
$modelCombo.Location = New-Object System.Drawing.Point(315, 195)
$modelCombo.Size = New-Object System.Drawing.Size(260, 25)
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
$languageLabel.Location = New-Object System.Drawing.Point(605, 170)
$languageLabel.Size = New-Object System.Drawing.Size(120, 22)
$form.Controls.Add($languageLabel)

$languageTextBox = New-Object System.Windows.Forms.TextBox
$languageTextBox.Location = New-Object System.Drawing.Point(605, 195)
$languageTextBox.Size = New-Object System.Drawing.Size(175, 25)
$languageTextBox.Text = $DefaultLanguage
$form.Controls.Add($languageTextBox)

# -----------------------------
# Buttons
# -----------------------------

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Start Transcription"
$startButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$startButton.Location = New-Object System.Drawing.Point(25, 245)
$startButton.Size = New-Object System.Drawing.Size(180, 38)
$form.Controls.Add($startButton)

$openInputButton = New-Object System.Windows.Forms.Button
$openInputButton.Text = "Open Input Folder"
$openInputButton.Location = New-Object System.Drawing.Point(225, 250)
$openInputButton.Size = New-Object System.Drawing.Size(155, 30)
$form.Controls.Add($openInputButton)

$openOutputButton = New-Object System.Windows.Forms.Button
$openOutputButton.Text = "Open Output Folder"
$openOutputButton.Location = New-Object System.Drawing.Point(395, 250)
$openOutputButton.Size = New-Object System.Drawing.Size(165, 30)
$form.Controls.Add($openOutputButton)

$clearStatusButton = New-Object System.Windows.Forms.Button
$clearStatusButton.Text = "Clear Status"
$clearStatusButton.Location = New-Object System.Drawing.Point(575, 250)
$clearStatusButton.Size = New-Object System.Drawing.Size(120, 30)
$form.Controls.Add($clearStatusButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Status: Ready"
$statusLabel.Location = New-Object System.Drawing.Point(25, 305)
$statusLabel.Size = New-Object System.Drawing.Size(755, 22)
$form.Controls.Add($statusLabel)

# -----------------------------
# Status output
# -----------------------------

$statusBox = New-Object System.Windows.Forms.TextBox
$statusBox.Location = New-Object System.Drawing.Point(25, 330)
$statusBox.Size = New-Object System.Drawing.Size(755, 220)
$statusBox.Multiline = $true
$statusBox.ScrollBars = "Vertical"
$statusBox.ReadOnly = $true
$statusBox.Font = New-Object System.Drawing.Font("Consolas", 9)
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

                Append-Status ""
                Append-Status "MediaScribe finished with exit code $exitCode."

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
            Append-Status ""
            Append-Status "MediaScribe process ended, but status could not be read."
            Set-RunningState -IsRunning $false
            $script:RunningProcess = $null
        }
    }
})

$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Choose an audio or video file"
    $dialog.InitialDirectory = $InputDir
    $dialog.Filter = "Media files|*.mp4;*.mkv;*.mov;*.m4v;*.avi;*.webm;*.mp3;*.m4a;*.wav;*.aac;*.flac;*.ogg;*.opus;*.wma|All files|*.*"

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $fileTextBox.Text = $dialog.FileName
    }
})

$openInputButton.Add_Click({
    Start-Process explorer.exe $InputDir
})

$openOutputButton.Add_Click({
    Start-Process explorer.exe $OutputDir
})

$clearStatusButton.Add_Click({
    $statusBox.Clear()
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

    $selectedFile = $fileTextBox.Text

    if ([string]::IsNullOrWhiteSpace($selectedFile) -or -not (Test-Path -LiteralPath $selectedFile)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Choose a valid audio or video file first.",
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
    Append-Status "MediaScribe GUI started."
    Append-Status "Selected file: $selectedFile"
    Append-Status "Output mode: $selectedOutputMode"
    Append-Status "Whisper model: $selectedModel"
    Append-Status "Language: $selectedLanguage"
    Append-Status ""

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

        $stdOutLog = $script:CurrentLogFile
        $stdErrLog = $script:CurrentLogFile

        $outJob = Start-Job -ScriptBlock {
            param($ProcessId, $LogPath)

            $proc = [System.Diagnostics.Process]::GetProcessById($ProcessId)

            while (-not $proc.HasExited) {
                Start-Sleep -Milliseconds 250
            }
        } -ArgumentList $process.Id, $script:CurrentLogFile

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
        Append-Status "Failed to start transcription."
        Append-Status $_.Exception.Message
        Set-RunningState -IsRunning $false
        $script:RunningProcess = $null
        $logTimer.Stop()
    }
})

$form.Add_FormClosing({
    try {
        $logTimer.Stop()
    } catch {
        # Ignore timer shutdown errors.
    }

    if ($null -ne $script:RunningProcess -and -not $script:RunningProcess.HasExited) {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "A transcription is still running. Close MediaScribe and stop the process?",
            "MediaScribe",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
            $_.Cancel = $true
            try {
                $logTimer.Start()
            } catch {
                # Ignore timer restart errors.
            }
            return
        }

        try {
            $script:RunningProcess.Kill()
        } catch {
            # Ignore shutdown errors.
        }
    }
})

Append-Status "MediaScribe GUI ready."
Append-Status "Input folder: $InputDir"
Append-Status "Output folder: $OutputDir"

[void]$form.ShowDialog()