<#
MediaScribe Setup Script

Creates or repairs a local MediaScribe install folder, copies the app files,
generates a clean config.json, creates a launcher, copies bundled dependencies,
and checks/assists with required dependencies.

This installer is designed for normal Windows users and does not require admin rights.

Install / repair policy:
- Required folders are created if missing.
- Existing files inside Input, Output, Logs, Models, and Tools are preserved.
- Core app files may be replaced during install or repair.
- config.json is regenerated for the selected install folder.

Dependency policy:
- FFmpeg is copied from Dependencies\FFmpeg if present.
- Python is checked first.
- If Python is missing, setup can launch a bundled Python installer.
- pip is checked only after Python is available.
- If pip is missing, setup can run python -m ensurepip --upgrade.
- Whisper is checked only after Python/pip are available.
- If Whisper is missing, setup can run python -m pip install -U openai-whisper.
- Each dependency step waits for the previous step to finish.
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

function Read-YesNo {
    param (
        [string]$Prompt,
        [string]$Default = "Y"
    )

    $choice = Read-Host $Prompt

    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = $Default
    }

    return ($choice.Trim().ToUpper() -eq "Y")
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

function Test-InternetAvailable {
    try {
        return [bool](Test-NetConnection -ComputerName "pypi.org" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue)
    } catch {
        return $false
    }
}

function Update-ProcessPathFromRegistry {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")

    $combinedPathParts = @()

    if (-not [string]::IsNullOrWhiteSpace($machinePath)) {
        $combinedPathParts += $machinePath
    }

    if (-not [string]::IsNullOrWhiteSpace($userPath)) {
        $combinedPathParts += $userPath
    }

    if ($combinedPathParts.Count -gt 0) {
        $env:Path = ($combinedPathParts -join ";")
    }
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

function Resolve-PythonCommand {
    Update-ProcessPathFromRegistry

    $pythonCommand = Get-Command "python" -ErrorAction SilentlyContinue

    if ($null -ne $pythonCommand) {
        try {
            $versionOutput = & $pythonCommand.Source --version 2>&1

            if ($LASTEXITCODE -eq 0 -and "$versionOutput" -match "Python") {
                return [pscustomobject]@{
                    Available = $true
                    Command   = $pythonCommand.Source
                    Version   = "$versionOutput"
                    Method    = "python command"
                }
            }
        } catch {
            # Continue to fallback checks.
        }
    }

    $possiblePythonRoots = @(
        (Join-Path $env:LocalAppData "Programs\Python"),
        "C:\Program Files\Python313",
        "C:\Program Files\Python314",
        "C:\Program Files\Python312"
    )

    foreach ($root in $possiblePythonRoots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        $pythonExe = Get-ChildItem -LiteralPath $root -Filter "python.exe" -Recurse -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1

        if ($null -ne $pythonExe) {
            try {
                $versionOutput = & $pythonExe.FullName --version 2>&1

                if ($LASTEXITCODE -eq 0 -and "$versionOutput" -match "Python") {
                    return [pscustomobject]@{
                        Available = $true
                        Command   = $pythonExe.FullName
                        Version   = "$versionOutput"
                        Method    = "located python.exe"
                    }
                }
            } catch {
                # Continue.
            }
        }
    }

    return [pscustomobject]@{
        Available = $false
        Command   = $null
        Version   = "not found"
        Method    = "not found"
    }
}

function Find-BundledPythonInstaller {
    param (
        [string]$ScriptRoot
    )

    $pythonDependencyFolder = Join-Path $ScriptRoot "Dependencies\Python"

    if (-not (Test-Path -LiteralPath $pythonDependencyFolder -PathType Container)) {
        return $null
    }

    $preferredInstaller = Get-ChildItem -LiteralPath $pythonDependencyFolder -Filter "python-3.13*-amd64.exe" -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1

    if ($null -ne $preferredInstaller) {
        return $preferredInstaller.FullName
    }

    $anyInstaller = Get-ChildItem -LiteralPath $pythonDependencyFolder -Filter "python-*-amd64.exe" -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1

    if ($null -ne $anyInstaller) {
        return $anyInstaller.FullName
    }

    return $null
}

function Install-BundledPython {
    param (
        [string]$PythonInstaller
    )

    Write-Section "Installing Python"

    Write-Host "Bundled Python installer:"
    Write-Host "  $PythonInstaller"
    Write-Host ""
    Write-Host "Python will be installed for the current user with pip enabled."
    Write-Host "This step may take a few minutes."
    Write-Host ""

    $installPython = Read-YesNo -Prompt "Install bundled Python now? (Y/N, default Y)" -Default "Y"

    if (-not $installPython) {
        Write-Warn "Python install skipped by user."
        return $false
    }

    $pythonArgs = @(
        "/passive",
        "InstallAllUsers=0",
        "PrependPath=1",
        "Include_pip=1",
        "Include_launcher=1",
        "Include_test=0"
    )

    try {
        $process = Start-Process -FilePath $PythonInstaller -ArgumentList $pythonArgs -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Ok "Bundled Python installer finished."
            Update-ProcessPathFromRegistry
            return $true
        }

        Write-Warn "Python installer exited with code $($process.ExitCode)."
        return $false
    } catch {
        Write-Warn "Python installer failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-PipAvailable {
    param (
        [string]$PythonCommand
    )

    if ([string]::IsNullOrWhiteSpace($PythonCommand)) {
        return [pscustomobject]@{
            Available = $false
            Version   = "not found"
        }
    }

    try {
        $pipVersion = & $PythonCommand -m pip --version 2>&1

        if ($LASTEXITCODE -eq 0) {
            return [pscustomobject]@{
                Available = $true
                Version   = "$pipVersion"
            }
        }
    } catch {
        # Continue to not found result.
    }

    return [pscustomobject]@{
        Available = $false
        Version   = "not found"
    }
}

function Install-PipWithEnsurePip {
    param (
        [string]$PythonCommand
    )

    Write-Section "Installing pip"

    if ([string]::IsNullOrWhiteSpace($PythonCommand)) {
        Write-Warn "Cannot install pip because Python is not available."
        return $false
    }

    Write-Host "pip was not found."
    Write-Host "Setup will try to enable pip using:"
    Write-Host "  python -m ensurepip --upgrade"
    Write-Host ""

    try {
        & $PythonCommand -m ensurepip --upgrade

        if ($LASTEXITCODE -eq 0) {
            Write-Ok "pip install/repair finished."
            return $true
        }

        Write-Warn "ensurepip exited with code $LASTEXITCODE."
        return $false
    } catch {
        Write-Warn "ensurepip failed: $($_.Exception.Message)"
        return $false
    }
}

function Find-WhisperCommand {
    param (
        [string]$PythonCommand
    )

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

    if (-not [string]::IsNullOrWhiteSpace($PythonCommand) -and (Test-Path -LiteralPath $PythonCommand -PathType Leaf)) {
        try {
            $pythonFolder = Split-Path $PythonCommand -Parent

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
    param (
        [string]$PythonCommand
    )

    if ([string]::IsNullOrWhiteSpace($PythonCommand)) {
        return $false
    }

    try {
        & $PythonCommand -m whisper --help *> $null

        if ($LASTEXITCODE -eq 0) {
            return $true
        }
    } catch {
        return $false
    }

    return $false
}

function Test-WhisperAvailable {
    param (
        [string]$PythonCommand
    )

    $result = [ordered]@{
        Available = $false
        Method    = "not found"
    }

    if (Test-PythonWhisper -PythonCommand $PythonCommand) {
        $result.Available = $true
        $result.Method = "python -m whisper"
        return $result
    }

    $whisperPath = Find-WhisperCommand -PythonCommand $PythonCommand

    if (-not [string]::IsNullOrWhiteSpace($whisperPath)) {
        $result.Available = $true
        $result.Method = $whisperPath
        return $result
    }

    return $result
}


function Install-WhisperWithPip {
    param (
        [string]$PythonCommand
    )

    Write-Section "Installing OpenAI Whisper"

    if ([string]::IsNullOrWhiteSpace($PythonCommand)) {
        Write-Warn "Cannot install Whisper because Python is not available."
        return $false
    }

    Write-Host "OpenAI Whisper was not found."
    Write-Host "Setup can install it with pip. Internet is required."
    Write-Host ""

    $installWhisper = Read-YesNo -Prompt "Install OpenAI Whisper now? (Y/N, default Y)" -Default "Y"

    if (-not $installWhisper) {
        Write-Warn "Whisper install skipped."
        return $false
    }

    Write-Host "Checking internet access..."

    if (-not (Test-InternetAvailable)) {
        Write-Warn "Internet check failed. Whisper install may not work."

        $tryAnyway = Read-YesNo -Prompt "Try anyway? (Y/N, default Y)" -Default "Y"

        if (-not $tryAnyway) {
            Write-Warn "Whisper install skipped."
            return $false
        }
    }

    Write-Host "Installing Whisper. This may take several minutes..."
    Write-Host ""

    try {
        & $PythonCommand -m pip install -U openai-whisper

        if ($LASTEXITCODE -eq 0) {
            Write-Ok "OpenAI Whisper install finished."
            return $true
        }

        Write-Warn "Whisper install failed. Check internet connection and run Install.bat again."
        return $false
    } catch {
        Write-Warn "Whisper install failed. Run Install.bat again later."
        return $false
    }
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

function Invoke-DependencySetup {
    param (
        [string]$InstallFolder,
        [string]$ScriptRoot
    )

    Write-Section "Dependency Check"

    # ---------------------------------------------------------
    # Python
    # ---------------------------------------------------------
    $pythonCheck = Resolve-PythonCommand

    if ($pythonCheck.Available) {
        Write-Ok "Python found through $($pythonCheck.Method): $($pythonCheck.Version)"
    } else {
        Write-Fail "Python was not found."
        Write-Host "MediaScribe needs Python before pip or Whisper can be used."
        Write-Host ""

        $pythonInstaller = Find-BundledPythonInstaller -ScriptRoot $ScriptRoot

        if (-not [string]::IsNullOrWhiteSpace($pythonInstaller)) {
            $pythonInstalled = Install-BundledPython -PythonInstaller $pythonInstaller

            if ($pythonInstalled) {
                $pythonCheck = Resolve-PythonCommand

                if ($pythonCheck.Available) {
                    Write-Ok "Python found after install: $($pythonCheck.Version)"
                } else {
                    Write-Warn "Python installer finished, but setup could not find python in this session."
                    Write-Host "You may need to close this window and run Install.bat again."
                }
            }
        } else {
            Write-Warn "No bundled Python installer was found in Dependencies\Python."
        }
    }

    # ---------------------------------------------------------
    # pip
    # ---------------------------------------------------------
    $pipCheck = [pscustomobject]@{
        Available = $false
        Version   = "not found"
    }

    if ($pythonCheck.Available) {
        $pipCheck = Test-PipAvailable -PythonCommand $pythonCheck.Command

        if ($pipCheck.Available) {
            Write-Ok "pip found: $($pipCheck.Version)"
        } else {
            $pipInstalled = Install-PipWithEnsurePip -PythonCommand $pythonCheck.Command

            if ($pipInstalled) {
                $pipCheck = Test-PipAvailable -PythonCommand $pythonCheck.Command

                if ($pipCheck.Available) {
                    Write-Ok "pip found after repair: $($pipCheck.Version)"
                } else {
                    Write-Warn "pip repair finished, but pip was still not found."
                }
            }
        }
    } else {
        Write-Warn "Skipping pip check because Python is not available."
    }

    # ---------------------------------------------------------
    # Whisper
    # ---------------------------------------------------------
    $whisperCheck = [ordered]@{
        Available = $false
        Method    = "not found"
    }

    if ($pythonCheck.Available -and $pipCheck.Available) {
        $whisperCheck = Test-WhisperAvailable -PythonCommand $pythonCheck.Command

        if ($whisperCheck.Available) {
            Write-Ok "OpenAI Whisper found through $($whisperCheck.Method)."
        } else {
            $whisperInstalled = Install-WhisperWithPip -PythonCommand $pythonCheck.Command

            if ($whisperInstalled) {
                $whisperCheck = Test-WhisperAvailable -PythonCommand $pythonCheck.Command

                if ($whisperCheck.Available) {
                    Write-Ok "OpenAI Whisper found after install through $($whisperCheck.Method)."
                } else {
                    Write-Warn "Whisper install finished, but setup could not verify it."
                }
            }
        }
    } elseif ($pythonCheck.Available -and -not $pipCheck.Available) {
        Write-Warn "Skipping Whisper install because pip is not available."
    } else {
        Write-Warn "Skipping Whisper check because Python is not available."
    }

    # ---------------------------------------------------------
    # FFmpeg
    # ---------------------------------------------------------
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

    $pythonAvailable = [bool]$pythonCheck.Available
    $pipAvailable = [bool]$pipCheck.Available
    $whisperAvailable = [bool]$whisperCheck.Available
    $whisperMethod = [string]$whisperCheck.Method

    $allReady = $pythonAvailable -and $pipAvailable -and $whisperAvailable -and $ffmpegAvailable

    Write-Host ""
    Write-Host "Dependency Summary:"
    Write-Host "  Python:  $pythonAvailable ($($pythonCheck.Method))"
    Write-Host "  pip:     $pipAvailable"
    Write-Host "  Whisper: $whisperAvailable ($whisperMethod)"
    Write-Host "  FFmpeg:  $ffmpegAvailable ($ffmpegMethod)"

    return [pscustomobject]@{
        PythonAvailable  = $pythonAvailable
        PythonCommand    = $pythonCheck.Command
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

$sourceFfmpegFolder = Join-Path $scriptRoot "Dependencies\FFmpeg"

if (Test-Path -LiteralPath $sourceFfmpegFolder -PathType Container) {
    $ffmpegExeSource = Join-Path $sourceFfmpegFolder "ffmpeg.exe"

    if (Test-Path -LiteralPath $ffmpegExeSource -PathType Leaf) {
        Write-Section "Copying Bundled FFmpeg"

        Copy-Item -Path (Join-Path $sourceFfmpegFolder "*") -Destination $ffmpegFolder -Recurse -Force
        Write-Ok "Copied bundled FFmpeg files from Dependencies\FFmpeg."
    } else {
        Write-Warn "Dependencies\FFmpeg exists, but ffmpeg.exe was not found."
        Write-Host "Setup will check for system FFmpeg during dependency check."
    }
}

$dependencyResult = Invoke-DependencySetup -InstallFolder $installFolder -ScriptRoot $scriptRoot

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
    Write-Host "  Run this launcher:"
    Write-Host "     $launcherPath"
    Write-Host ""
    Write-Host "  Audio/video files go in:"
    Write-Host "     $inputFolder"
    Write-Host ""
    Write-Host "  Transcripts and caption files will be created in:"
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
    Write-Host "After fixing the missing dependencies, run Install.bat again to re-check setup."
    Write-Host ""
}

Write-Host "To remove MediaScribe, delete the installed MediaScribe folder:"
Write-Host "  $installFolder"
Write-Host ""

if ($dependencyResult.AllReady) {
    $runNow = Read-YesNo -Prompt "Run MediaScribe now? (Y/N, default Y)" -Default "Y"

    if ($runNow -eq "Y") {
        Write-Host ""
        Write-Host "Starting MediaScribe..."
        Write-Host ""

        Push-Location $installFolder
        try {
            & $launcherPath
        } finally {
            Pop-Location
        }
    }
} else {
    Write-Host "MediaScribe was installed, but it cannot run yet because one or more dependencies are missing."
    Write-Host "After fixing dependencies, run Install.bat again."
}

Write-Host ""
Write-Ok "Done."