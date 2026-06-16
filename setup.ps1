<#
MediaScribe Setup Script

Creates or repairs a local MediaScribe install folder, copies the app files,
generates a clean config.json, creates a launcher, and checks dependencies.

This installer is designed for normal Windows users and does not require admin rights.

Install / repair policy:
- Required folders are created if missing.
- Existing files inside Input, Output, Logs, Models, and Tools are preserved.
- Core app files may be replaced during install or repair.
- config.json is regenerated for the selected install folder.
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

function Copy-AppFile {
    param (
        [string]$SourcePath,
        [string]$DestinationPath,
        [bool]$Required = $true
    )

    if (Test-Path -LiteralPath $SourcePath -PathType Leaf) {
        Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
        Write-Ok "Copied $(Split-Path $SourcePath -Leaf)"
        return
    }

    if ($Required) {
        throw "Required setup file is missing: $SourcePath"
    }

    Write-Warn "Optional file not found, skipping: $(Split-Path $SourcePath -Leaf)"
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
                if (Test-Path -LiteralPath $possiblePath -PathType Leaf) {
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

function Test-WhisperAvailable {
    $result = [ordered]@{
        Available = $false
        Method    = "not found"
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

function Test-FFmpegAvailable {
    param (
        [string]$InstallFolder
    )

    $result = [ordered]@{
        Available = $false
        Method    = "not found"
        Detail    = "not found"
    }

    $localFfmpeg = Join-Path $InstallFolder "Tools\ffmpeg\ffmpeg.exe"

    if (Test-Path -LiteralPath $localFfmpeg -PathType Leaf) {
        $result.Available = $true
        $result.Method = "local Tools\ffmpeg"
        $result.Detail = $localFfmpeg
        return $result
    }

    $systemFfmpeg = Get-Command "ffmpeg" -ErrorAction SilentlyContinue

    if ($null -ne $systemFfmpeg) {
        $ffmpegVersion = & ffmpeg -version 2>&1 | Select-Object -First 1

        $result.Available = $true
        $result.Method = "system PATH"
        $result.Detail = $ffmpegVersion
        return $result
    }

    $result.Detail = "No bundled FFmpeg was found in Tools\ffmpeg and no system FFmpeg was found in PATH."
    return $result
}

function Invoke-DependencyCheck {
    param (
        [string]$InstallFolder
    )

    Write-Section "Dependency Check"

    $pythonAvailable = Test-CommandExists -Command "python"
    $pipAvailable = $false

    if ($pythonAvailable) {
        try {
            $pythonVersion = & python --version 2>&1
            Write-Ok "Python found: $pythonVersion"
        } catch {
            Write-Warn "Python command was found, but version check failed."
        }

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
            Write-Fail "pip was not found."
            Write-Host "OpenAI Whisper usually requires pip for installation."
        }
    } else {
        Write-Fail "Python was not found."
        Write-Host "MediaScribe usually requires Python and OpenAI Whisper."
    }

    $whisperCheck = Test-WhisperAvailable
    $whisperAvailable = [bool]$whisperCheck.Available
    $whisperMethod = [string]$whisperCheck.Method

    if ($whisperAvailable) {
        Write-Ok "OpenAI Whisper found through $whisperMethod."
    } else {
        Write-Fail "OpenAI Whisper was not found."
        Write-Host "MediaScribe cannot transcribe until Whisper is installed."
        Write-Host "Whisper lookup tried:"
        Write-Host "  1. python -m whisper"
        Write-Host "  2. global whisper.exe / whisper command"
    }

    $ffmpegCheck = Test-FFmpegAvailable -InstallFolder $InstallFolder
    $ffmpegAvailable = [bool]$ffmpegCheck.Available
    $ffmpegMethod = [string]$ffmpegCheck.Method
    $ffmpegDetail = [string]$ffmpegCheck.Detail

    if ($ffmpegAvailable) {
        Write-Ok "FFmpeg found through $ffmpegMethod`: $ffmpegDetail"
    } else {
        $localFfmpeg = Join-Path $InstallFolder "Tools\ffmpeg\ffmpeg.exe"

        Write-Fail "FFmpeg was not found."
        Write-Host "MediaScribe cannot transcribe until FFmpeg is available."
        Write-Host "FFmpeg lookup tried:"
        Write-Host "  1. $localFfmpeg"
        Write-Host "  2. system ffmpeg from PATH"
    }

    $allReady = $pythonAvailable -and $pipAvailable -and $whisperAvailable -and $ffmpegAvailable

    Write-Host ""
    Write-Host "Dependency Summary:"
    Write-Host "  Python:  $pythonAvailable"
    Write-Host "  pip:     $pipAvailable"
    Write-Host "  Whisper: $whisperAvailable ($whisperMethod)"
    Write-Host "  FFmpeg:  $ffmpegAvailable ($ffmpegMethod)"

    return [pscustomobject]@{
        PythonAvailable  = $pythonAvailable
        PipAvailable     = $pipAvailable
        WhisperAvailable = $whisperAvailable
        WhisperMethod    = $whisperMethod
        FFmpegAvailable  = $ffmpegAvailable
        FFmpegMethod     = $ffmpegMethod
        AllReady         = $allReady
    }
}

Write-Section "MediaScribe Setup"

Write-Host "MediaScribe creates transcripts and caption files from audio/video files."
Write-Host ""
Write-Host "This setup will install or repair MediaScribe in a local folder."
Write-Host ""
Write-Host "Setup will create these folders if they are missing:"
Write-Host "  Input"
Write-Host "  Output"
Write-Host "  Logs"
Write-Host "  Models"
Write-Host "  Tools"
Write-Host ""
Write-Host "Existing files inside those folders are preserved."
Write-Host "Core app files may be replaced during install or repair."
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

Write-Info "Existing files inside Input, Output, Logs, Models, and Tools are preserved."

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

$configObject = [ordered]@{
    AppName                             = "MediaScribe"
    BaseFolder                          = $installFolder
    InputFolder                         = $inputFolder
    OutputFolder                        = $outputFolder
    LogsFolder                          = $logsFolder
    ModelsFolder                        = $modelsFolder
    DefaultModel                        = "medium"
    DefaultLanguage                     = "en"
    OutputMode                          = "default"
    MoveInputFolderFilesAfterProcessing = $true
    ExternalFileArchiveBehavior         = "LeaveOriginalInPlace"
}

$configJson = $configObject | ConvertTo-Json -Depth 5
$configJson | Set-Content -Path $configPath -Encoding UTF8

Write-Ok "Created config.json"

Write-Section "Creating Launcher"

$launcherPath = Join-Path $installFolder "MediaScribe.bat"

$launcherContent = @"
@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0transcribe.ps1"
"@

$launcherContent | Set-Content -Path $launcherPath -Encoding ASCII

Write-Ok "Created MediaScribe.bat"

$sourceFfmpegFolder = Join-Path $scriptRoot "Tools\ffmpeg"

if (Test-Path -LiteralPath $sourceFfmpegFolder -PathType Container) {
    Write-Section "Copying Bundled FFmpeg"

    Copy-Item -Path (Join-Path $sourceFfmpegFolder "*") -Destination $ffmpegFolder -Recurse -Force
    Write-Ok "Copied bundled FFmpeg files."
}

$dependencyResult = Invoke-DependencyCheck -InstallFolder $installFolder

if ($dependencyResult.AllReady) {
    Write-Section "Setup Complete"
} else {
    Write-Section "Setup Complete - Missing Dependencies"
}

Write-Host "MediaScribe is installed here:"
Write-Host "  $installFolder"
Write-Host ""

Write-Host "Install / repair notes:"
Write-Host "  Core app files were copied or replaced."
Write-Host "  Existing files inside Input, Output, Logs, Models, and Tools were preserved."
Write-Host ""

if ($dependencyResult.AllReady) {
    Write-Host "To use MediaScribe:"
    Write-Host "  1. Put audio/video files in:"
    Write-Host "     $inputFolder"
    Write-Host ""
    Write-Host "  2. Run:"
    Write-Host "     $launcherPath"
    Write-Host ""
    Write-Host "  3. Transcripts and caption files will be created in:"
    Write-Host "     $outputFolder"
    Write-Host ""
} else {
    Write-Host "MediaScribe files were installed, but transcription will not work until the missing dependencies are fixed."
    Write-Host ""
    Write-Host "Required dependencies:"
    Write-Host "  Python"
    Write-Host "  pip"
    Write-Host "  OpenAI Whisper"
    Write-Host "  FFmpeg"
    Write-Host ""
    Write-Host "After installing the missing dependencies, run Install.bat again to re-check setup."
    Write-Host ""
}

Write-Host "To remove MediaScribe, delete the installed MediaScribe folder:"
Write-Host "  $installFolder"
Write-Host ""

$openFolder = Read-Host "Open the MediaScribe folder now? (Y/N, default Y)"

if ([string]::IsNullOrWhiteSpace($openFolder) -or $openFolder.Trim().ToUpper() -eq "Y") {
    Start-Process explorer.exe -ArgumentList "`"$installFolder`""
}

Write-Host ""
Write-Ok "Done."