<#
MediaScribe Setup Script

Creates a local MediaScribe install folder, copies the app files,
generates a clean config.json, creates a launcher, and checks dependencies.

This installer is designed for normal Windows users and does not require admin rights.
#>

$ErrorActionPreference = "Stop"

function Write-Section {
    param (
        [string]$Title
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Write-Info {
    param (
        [string]$Message
    )

    Write-Host "[INFO] $Message"
}

function Write-Ok {
    param (
        [string]$Message
    )

    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param (
        [string]$Message
    )

    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param (
        [string]$Message
    )

    Write-Host "[MISSING] $Message" -ForegroundColor Red
}

function Backup-ExistingFile {
    param (
        [string]$Path
    )

    if (Test-Path $Path) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$Path.bak_$timestamp"
        Copy-Item -Path $Path -Destination $backupPath -Force
        Write-Warn "Existing file backed up: $backupPath"
    }
}

function Copy-AppFile {
    param (
        [string]$SourcePath,
        [string]$DestinationPath,
        [bool]$Required = $true
    )

    if (Test-Path $SourcePath) {
        Backup-ExistingFile -Path $DestinationPath
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
        Write-Ok "Copied $(Split-Path $SourcePath -Leaf)"
    } else {
        if ($Required) {
            throw "Required setup file is missing: $SourcePath"
        } else {
            Write-Warn "Optional file not found, skipping: $(Split-Path $SourcePath -Leaf)"
        }
    }
}

function Test-CommandExists {
    param (
        [string]$Command
    )

    $found = Get-Command $Command -ErrorAction SilentlyContinue
    return $null -ne $found
}

function Select-InstallFolder {
    param (
        [string]$DefaultPath
    )

    Write-Host "Default install folder:"
    Write-Host "  $DefaultPath"
    Write-Host ""

    Write-Host "Choose install location:"
    Write-Host "  [Enter] Use default"
    Write-Host "  [B] Browse for a folder"
    Write-Host "  [T] Type a folder path"
    Write-Host ""

    $choice = Read-Host "Choice (default Enter)"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        return $DefaultPath
    }

    switch ($choice.Trim().ToUpper()) {
        "B" {
            Add-Type -AssemblyName System.Windows.Forms

            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "Choose where to install MediaScribe"
            $dialog.SelectedPath = $DefaultPath
            $dialog.ShowNewFolderButton = $true

            $result = $dialog.ShowDialog()

            if ($result -eq [System.Windows.Forms.DialogResult]::OK -and
                -not [string]::IsNullOrWhiteSpace($dialog.SelectedPath)) {
                return $dialog.SelectedPath
            }

            Write-Warn "No folder selected. Using default install folder."
            return $DefaultPath
        }

        "T" {
            $typedPath = Read-Host "Type install folder path"

            if ([string]::IsNullOrWhiteSpace($typedPath)) {
                Write-Warn "No path entered. Using default install folder."
                return $DefaultPath
            }

            return $typedPath.Trim()
        }

        default {
            Write-Warn "Unknown choice. Using default install folder."
            return $DefaultPath
        }
    }
}

function Find-WhisperCommand {
    $globalWhisper = Get-Command "whisper" -ErrorAction SilentlyContinue

    if ($null -ne $globalWhisper) {
        return $globalWhisper.Source
    }

    try {
        $whereWhisper = where.exe whisper 2>$null | Select-Object -First 1

        if (-not [string]::IsNullOrWhiteSpace($whereWhisper)) {
            return $whereWhisper.Trim()
        }
    } catch {
        # Continue to Python Scripts fallback.
    }

    if (Test-CommandExists -Command "python") {
        try {
            $pythonExe = (Get-Command python).Source
            $pythonFolder = Split-Path $pythonExe -Parent

            $possibleWhisperPaths = @(
                (Join-Path $pythonFolder "Scripts\whisper.exe"),
                (Join-Path $pythonFolder "Scripts\whisper.cmd"),
                (Join-Path $pythonFolder "Scripts\whisper")
            )

            foreach ($possiblePath in $possibleWhisperPaths) {
                if (Test-Path $possiblePath) {
                    return $possiblePath
                }
            }
        } catch {
            return $null
        }
    }

    return $null
}

function Test-PythonWhisper {
    if (-not (Test-CommandExists -Command "python")) {
        return $false
    }

    try {
        & python -m whisper --help *> $null

        if ($LASTEXITCODE -eq 0) {
            return $true
        }
    } catch {
        return $false
    }

    return $false
}

function Test-GlobalWhisper {
    $whisperPath = Find-WhisperCommand

    if ([string]::IsNullOrWhiteSpace($whisperPath)) {
        return $false
    }

    return $true
}

function Test-WhisperAvailable {
    $result = [ordered]@{
        Available = $false
        Method = "Not found"
    }

    if (Test-PythonWhisper) {
        $result.Available = $true
        $result.Method = "python -m whisper"
        return $result
    }

    $whisperPath = Find-WhisperCommand

    if (-not [string]::IsNullOrWhiteSpace($whisperPath)) {
        $result.Available = $true
        $result.Method = $whisperPath
        return $result
    }

    return $result
}

function Invoke-DependencyCheck {
    param (
        [string]$InstallFolder
    )

    Write-Section "Dependency Check"

    $pythonAvailable = Test-CommandExists -Command "python"
    $pipAvailable = $false
    $whisperAvailable = $false
    $whisperMethod = "Not found"
    $ffmpegAvailable = $false
    $ffmpegMethod = "Not found"

    if ($pythonAvailable) {
        $pythonVersion = & python --version 2>&1
        Write-Ok "Python found: $pythonVersion"

        try {
            $pipVersion = & python -m pip --version 2>&1

            if ($LASTEXITCODE -eq 0) {
                $pipAvailable = $true
                Write-Ok "pip found: $pipVersion"
            }
        } catch {
            $pipAvailable = $false
        }

        if (-not $pipAvailable) {
            Write-Warn "pip was not found. Attempting to enable pip with ensurepip..."

            try {
                & python -m ensurepip --upgrade
                & python -m pip install --upgrade pip
                $pipVersion = & python -m pip --version 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $pipAvailable = $true
                    Write-Ok "pip is now available: $pipVersion"
                }
            } catch {
                Write-Fail "pip could not be enabled automatically."
            }
        }
    } else {
        Write-Fail "Python was not found."
        Write-Host ""
        Write-Host "MediaScribe usually requires Python and OpenAI Whisper."
        Write-Host "If the standalone whisper command is available, MediaScribe may still work."
        Write-Host "Otherwise, install Python from python.org, then run this setup again."
    }

    $whisperCheck = Test-WhisperAvailable
    $whisperAvailable = [bool]$whisperCheck.Available
    $whisperMethod = [string]$whisperCheck.Method

    if ($whisperAvailable) {
        Write-Ok "OpenAI Whisper found through $whisperMethod."
    } else {
        Write-Warn "OpenAI Whisper was not found through python -m whisper or the global whisper command."

        if ($pythonAvailable -and $pipAvailable) {
            Write-Host ""
            Write-Host "Whisper is required for transcription."
            Write-Host "Installing it can take several minutes and requires internet access."
            Write-Host ""

            $installWhisper = Read-Host "Install OpenAI Whisper now? (Y/N, default Y)"

            if ([string]::IsNullOrWhiteSpace($installWhisper) -or $installWhisper.Trim().ToUpper() -eq "Y") {
                Write-Info "Installing OpenAI Whisper..."
                & python -m pip install -U openai-whisper

                $whisperCheck = Test-WhisperAvailable
                $whisperAvailable = [bool]$whisperCheck.Available
                $whisperMethod = [string]$whisperCheck.Method

                if ($whisperAvailable) {
                    Write-Ok "OpenAI Whisper installed successfully and verified through $whisperMethod."
                } else {
                    Write-Fail "Whisper install was attempted, but Whisper did not verify successfully."
                }
            } else {
                Write-Warn "Skipped Whisper install."
            }
        } else {
            Write-Warn "Whisper cannot be installed automatically because Python or pip is missing."
        }
    }

    $localFfmpeg = Join-Path $InstallFolder "Tools\ffmpeg\ffmpeg.exe"

    if (Test-Path $localFfmpeg) {
        $ffmpegAvailable = $true
        $ffmpegMethod = "local Tools\ffmpeg"
        Write-Ok "Local FFmpeg found: $localFfmpeg"
    } elseif (Test-CommandExists -Command "ffmpeg") {
        $ffmpegVersion = & ffmpeg -version 2>&1 | Select-Object -First 1
        $ffmpegAvailable = $true
        $ffmpegMethod = "system PATH"
        Write-Ok "System FFmpeg found: $ffmpegVersion"
    } else {
        Write-Fail "FFmpeg was not found."
        Write-Host ""
        Write-Host "MediaScribe requires FFmpeg to extract audio from media files."
        Write-Host "Future setup versions may bundle FFmpeg automatically."
        Write-Host "For now, install FFmpeg or place ffmpeg.exe here:"
        Write-Host "  $localFfmpeg"
    }

    Write-Host ""
    Write-Host "Dependency Summary:"
    Write-Host "  Python:  $pythonAvailable"
    Write-Host "  pip:     $pipAvailable"
    Write-Host "  Whisper: $whisperAvailable ($whisperMethod)"
    Write-Host "  FFmpeg:  $ffmpegAvailable ($ffmpegMethod)"
}

Write-Section "MediaScribe Setup"

Write-Host "MediaScribe creates transcripts and caption files from audio/video files."
Write-Host ""
Write-Host "This setup will install MediaScribe to a local folder and create:"
Write-Host "  Input"
Write-Host "  Output"
Write-Host "  Logs"
Write-Host "  Models"
Write-Host "  Tools"
Write-Host ""

$defaultInstallFolder = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "MediaScribe"

$installFolder = Select-InstallFolder -DefaultPath $defaultInstallFolder
$installFolder = [System.IO.Path]::GetFullPath($installFolder)

Write-Host ""
Write-Host "MediaScribe will be installed to:"
Write-Host "  $installFolder"
Write-Host ""

$confirm = Read-Host "Continue? (Y/N, default Y)"

if (-not [string]::IsNullOrWhiteSpace($confirm) -and $confirm.Trim().ToUpper() -ne "Y") {
    Write-Warn "Setup canceled."
    exit 0
}

Write-Section "Creating Folders"

$inputFolder = Join-Path $installFolder "Input"
$outputFolder = Join-Path $installFolder "Output"
$logsFolder = Join-Path $installFolder "Logs"
$modelsFolder = Join-Path $installFolder "Models"
$toolsFolder = Join-Path $installFolder "Tools"
$ffmpegFolder = Join-Path $toolsFolder "ffmpeg"

$folders = @(
    $installFolder,
    $inputFolder,
    $outputFolder,
    $logsFolder,
    $modelsFolder,
    $toolsFolder,
    $ffmpegFolder
)

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    Write-Ok "Folder ready: $folder"
}

Write-Section "Copying App Files"

$scriptRoot = $PSScriptRoot

$sourceTranscribe = Join-Path $scriptRoot "transcribe.ps1"
$sourceReadme = Join-Path $scriptRoot "README.md"
$sourceHowToStart = Join-Path $scriptRoot "How to Start transcription.txt"

$destTranscribe = Join-Path $installFolder "transcribe.ps1"
$destReadme = Join-Path $installFolder "README.md"
$destHowToStart = Join-Path $installFolder "How to Start transcription.txt"

Copy-AppFile -SourcePath $sourceTranscribe -DestinationPath $destTranscribe -Required $true
Copy-AppFile -SourcePath $sourceReadme -DestinationPath $destReadme -Required $false
Copy-AppFile -SourcePath $sourceHowToStart -DestinationPath $destHowToStart -Required $false

Write-Section "Creating Config"

$configPath = Join-Path $installFolder "config.json"
Backup-ExistingFile -Path $configPath

$configObject = [ordered]@{
    AppName = "MediaScribe"
    BaseFolder = $installFolder
    InputFolder = $inputFolder
    OutputFolder = $outputFolder
    LogsFolder = $logsFolder
    ModelsFolder = $modelsFolder
    DefaultModel = "medium"
    DefaultLanguage = "en"
    OutputMode = "default"
    MoveInputFolderFilesAfterProcessing = $true
    ExternalFileArchiveBehavior = "LeaveOriginalInPlace"
}

$configJson = $configObject | ConvertTo-Json -Depth 5
$configJson | Set-Content -Path $configPath -Encoding UTF8

Write-Ok "Created config.json"

Write-Section "Creating Launcher"

$launcherPath = Join-Path $installFolder "MediaScribe.bat"
Backup-ExistingFile -Path $launcherPath

$launcherContent = @"
@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0transcribe.ps1"
"@

$launcherContent | Set-Content -Path $launcherPath -Encoding ASCII

Write-Ok "Created MediaScribe.bat"

Write-Section "Copying Bundled FFmpeg If Present"

$sourceFfmpegFolder = Join-Path $scriptRoot "Tools\ffmpeg"

if (Test-Path $sourceFfmpegFolder) {
    Copy-Item -Path (Join-Path $sourceFfmpegFolder "*") -Destination $ffmpegFolder -Recurse -Force
    Write-Ok "Copied bundled FFmpeg files."
} else {
    Write-Warn "No bundled FFmpeg folder found in setup package."
}

Invoke-DependencyCheck -InstallFolder $installFolder

Write-Section "Setup Complete"

Write-Host "MediaScribe is installed here:"
Write-Host "  $installFolder"
Write-Host ""
Write-Host "To use it:"
Write-Host "  1. Put audio/video files in:"
Write-Host "     $inputFolder"
Write-Host ""
Write-Host "  2. Run:"
Write-Host "     $launcherPath"
Write-Host ""
Write-Host "  3. Transcripts and caption files will be created in:"
Write-Host "     $outputFolder"
Write-Host ""

$openFolder = Read-Host "Open the MediaScribe folder now? (Y/N, default Y)"

if ([string]::IsNullOrWhiteSpace($openFolder) -or $openFolder.Trim().ToUpper() -eq "Y") {
    Start-Process explorer.exe -ArgumentList "`"$installFolder`""
}

Write-Host ""
Write-Ok "Done."