# =====================================================
# Transcribe.ps1 - Archive-style transcription workflow
# Configuration is loaded from config.json next to this script.
# =====================================================

param(
    [string]$InputFile,
    [string]$OutputFolder,
    [string]$Model,
    [string]$Language,

    [ValidateSet("default", "full")]
    [string]$OutputMode,

    [ValidateSet("transcribe", "translate")]
    [string]$Task
)

function New-DefaultConfig {
  $defaultBaseFolder = $PSScriptRoot

  [ordered]@{
    AppName                              = "MediaScribe"
    BaseFolder                           = $defaultBaseFolder
    InputFolder                          = Join-Path $defaultBaseFolder "Input"
    OutputFolder                         = Join-Path $defaultBaseFolder "Output"
    LogsFolder                           = Join-Path $defaultBaseFolder "Logs"
    ModelsFolder                         = Join-Path $defaultBaseFolder "Models"
    DefaultModel                         = "medium"
    DefaultLanguage                      = "en"
    OutputMode                           = "default"
    MoveInputFolderFilesAfterProcessing  = $true
    ExternalFileArchiveBehavior          = "LeaveOriginalInPlace"
  }
}

function Get-ConfigValue {
  param(
    [object]$Config,
    [string]$Name,
    [object]$DefaultValue
  )

  if ($null -eq $Config) {
    return $DefaultValue
  }

  $property = $Config.PSObject.Properties[$Name]
  if ($null -eq $property -or $null -eq $property.Value) {
    return $DefaultValue
  }

  if ($property.Value -is [string] -and [string]::IsNullOrWhiteSpace($property.Value)) {
    return $DefaultValue
  }

  return $property.Value
}

function Resolve-ConfiguredPath {
  param(
    [string]$PathValue,
    [string]$BaseFolder
  )

  if ([string]::IsNullOrWhiteSpace($PathValue)) {
    return $PathValue
  }

  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return $PathValue
  }

  return Join-Path $BaseFolder $PathValue
}

function Test-CommandExists {
  param(
    [string]$Command
  )

  $foundCommand = Get-Command $Command -ErrorAction SilentlyContinue
  return ($null -ne $foundCommand)
}

function Resolve-FFmpegCommand {
  param(
    [string]$BaseFolder
  )

  $localFFmpeg = Join-Path $BaseFolder "Tools\ffmpeg\ffmpeg.exe"

  if (Test-Path -LiteralPath $localFFmpeg) {
    return [pscustomobject]@{
      Found    = $true
      FilePath = $localFFmpeg
      Source   = "local Tools\ffmpeg"
    }
  }

  $systemFFmpeg = Get-Command "ffmpeg" -ErrorAction SilentlyContinue

  if ($null -ne $systemFFmpeg) {
    return [pscustomobject]@{
      Found    = $true
      FilePath = $systemFFmpeg.Source
      Source   = "system PATH"
    }
  }

  return [pscustomobject]@{
    Found    = $false
    FilePath = $null
    Source   = "not found"
  }
}

function Resolve-WhisperCommand {
  $pythonCommand = Get-Command "python" -ErrorAction SilentlyContinue

  if ($null -ne $pythonCommand) {
    return [pscustomobject]@{
      Found    = $true
      FilePath = $pythonCommand.Source
      Mode     = "PythonModule"
      Source   = "python -m whisper"
    }
  }

  $whisperCommand = Get-Command "whisper" -ErrorAction SilentlyContinue

  if ($null -ne $whisperCommand) {
    return [pscustomobject]@{
      Found    = $true
      FilePath = $whisperCommand.Source
      Mode     = "Command"
      Source   = "whisper command"
    }
  }

  return [pscustomobject]@{
    Found    = $false
    FilePath = $null
    Mode     = "Missing"
    Source   = "not found"
  }
}

function Normalize-OutputMode {
  param(
    [string]$Mode
  )

  if ([string]::IsNullOrWhiteSpace($Mode)) {
    return "default"
  }

  $normalized = $Mode.Trim().ToLower()

  if ($normalized -eq "full") {
    return "full"
  }

  return "default"
}

function Normalize-WhisperLanguage {
  param(
    [string]$LanguageValue,
    [string]$FallbackLanguage = "en"
  )

  if ([string]::IsNullOrWhiteSpace($LanguageValue)) {
    return $FallbackLanguage
  }

  $normalized = $LanguageValue.Trim().ToLowerInvariant()

  if ($normalized -in @("auto", "auto-detect", "autodetect", "detect")) {
    return "auto"
  }

  return $normalized
}

function Normalize-WhisperTask {
  param(
    [string]$TaskValue
  )

  if ([string]::IsNullOrWhiteSpace($TaskValue)) {
    return "transcribe"
  }

  $normalized = $TaskValue.Trim().ToLowerInvariant()

  if ($normalized -eq "translate") {
    return "translate"
  }

  return "transcribe"
}

function Get-ExpectedOutputExtensions {
  param(
    [string]$SelectedOutputMode
  )

  if ($SelectedOutputMode -eq "full") {
    return @(".txt", ".srt", ".vtt", ".tsv", ".json")
  }

  return @(".txt")
}

function Get-UniqueDestinationPath {
  param(
    [string]$FolderPath,
    [string]$FileName
  )

  $destination = Join-Path $FolderPath $FileName

  if (-not (Test-Path -LiteralPath $destination)) {
    return $destination
  }

  $nameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
  $extension = [System.IO.Path]::GetExtension($FileName)

  $counter = 1

  do {
    $candidateName = "{0}_{1}{2}" -f $nameWithoutExtension, $counter, $extension
    $candidatePath = Join-Path $FolderPath $candidateName
    $counter++
  } while (Test-Path -LiteralPath $candidatePath)

  return $candidatePath
}

function Test-PathInsideFolder {
  param(
    [string]$ChildPath,
    [string]$ParentPath
  )

  try {
    $resolvedChild = (Resolve-Path -LiteralPath $ChildPath).ProviderPath
    $resolvedParent = (Resolve-Path -LiteralPath $ParentPath).ProviderPath

    $parentWithSlash = $resolvedParent.TrimEnd('\') + '\'

    return $resolvedChild.StartsWith($parentWithSlash, [System.StringComparison]::OrdinalIgnoreCase)
  } catch {
    return $false
  }
}

$ConfigPath = Join-Path $PSScriptRoot "config.json"

if (Test-Path -LiteralPath $ConfigPath) {
  try {
    $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
  } catch {
    Write-Host "Could not read config.json. Using built-in defaults." -ForegroundColor Yellow
    $Config = New-DefaultConfig
  }
} else {
  $Config = New-DefaultConfig
}

$BaseFolder = Get-ConfigValue -Config $Config -Name "BaseFolder" -DefaultValue $PSScriptRoot
$InputDir = Resolve-ConfiguredPath -PathValue (Get-ConfigValue -Config $Config -Name "InputFolder" -DefaultValue (Join-Path $BaseFolder "Input")) -BaseFolder $BaseFolder
$OutputDir = Resolve-ConfiguredPath -PathValue (Get-ConfigValue -Config $Config -Name "OutputFolder" -DefaultValue (Join-Path $BaseFolder "Output")) -BaseFolder $BaseFolder
$LogsDir = Resolve-ConfiguredPath -PathValue (Get-ConfigValue -Config $Config -Name "LogsFolder" -DefaultValue (Join-Path $BaseFolder "Logs")) -BaseFolder $BaseFolder
$ModelsDir = Resolve-ConfiguredPath -PathValue (Get-ConfigValue -Config $Config -Name "ModelsFolder" -DefaultValue (Join-Path $BaseFolder "Models")) -BaseFolder $BaseFolder

$DefaultModel = Get-ConfigValue -Config $Config -Name "DefaultModel" -DefaultValue "medium"
$DefaultLanguage = Get-ConfigValue -Config $Config -Name "DefaultLanguage" -DefaultValue "en"
$DefaultOutputMode = Get-ConfigValue -Config $Config -Name "OutputMode" -DefaultValue "default"
$MoveInputFolderFilesAfterProcessing = [bool](Get-ConfigValue -Config $Config -Name "MoveInputFolderFilesAfterProcessing" -DefaultValue $true)
$ExternalFileArchiveBehavior = Get-ConfigValue -Config $Config -Name "ExternalFileArchiveBehavior" -DefaultValue "LeaveOriginalInPlace"

if (-not [string]::IsNullOrWhiteSpace($OutputFolder)) {
  $OutputDir = $OutputFolder
}

if (-not [string]::IsNullOrWhiteSpace($Model)) {
  $DefaultModel = $Model
}

if (-not [string]::IsNullOrWhiteSpace($Language)) {
  $DefaultLanguage = $Language
}

$DefaultLanguage = Normalize-WhisperLanguage -LanguageValue $DefaultLanguage -FallbackLanguage "en"

# Allow command-line / future GUI mode to override configured output mode.
if (-not [string]::IsNullOrWhiteSpace($OutputMode)) {
    $DefaultOutputMode = $OutputMode.ToLowerInvariant()
}

$NormalizedOutputMode = Normalize-OutputMode -Mode $DefaultOutputMode
$WhisperTask = Normalize-WhisperTask -TaskValue $Task

$ParameterMode = -not [string]::IsNullOrWhiteSpace($InputFile)

foreach ($folder in @($InputDir, $OutputDir, $LogsDir, $ModelsDir)) {
  if (-not (Test-Path -LiteralPath $folder)) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
  }
}

$ResolvedFFmpegCommand = Resolve-FFmpegCommand -BaseFolder $BaseFolder
$ResolvedWhisperCommand = Resolve-WhisperCommand

if (-not $ParameterMode) {
  Write-Host ""
  Write-Host "Dependency check:"
  if ($ResolvedFFmpegCommand.Found) {
    Write-Host "  FFmpeg:  $($ResolvedFFmpegCommand.Source) - $($ResolvedFFmpegCommand.FilePath)" -ForegroundColor Green
  } else {
    Write-Host "  FFmpeg:  not found" -ForegroundColor Red
  }

  if ($ResolvedWhisperCommand.Found) {
    Write-Host "  Whisper: $($ResolvedWhisperCommand.Source) - $($ResolvedWhisperCommand.FilePath)" -ForegroundColor Green
  } else {
    Write-Host "  Whisper: not found" -ForegroundColor Red
  }
}

if (-not $ResolvedFFmpegCommand.Found) {
  Write-Host ""
  Write-Host "FFmpeg was not found." -ForegroundColor Red
  Write-Host "Expected local FFmpeg here:"
  Write-Host "  $(Join-Path $BaseFolder "Tools\ffmpeg\ffmpeg.exe")"
  Write-Host ""
  Write-Host "Or install FFmpeg and make sure ffmpeg is available from PATH."
  exit 1
}

if (-not $ResolvedWhisperCommand.Found) {
  Write-Host ""
  Write-Host "OpenAI Whisper was not found through python -m whisper or the global whisper command." -ForegroundColor Red
  Write-Host "Install Whisper, or make sure the whisper command is available from PATH."
  exit 1
}

# Start the interactive app with a clean screen after dependency checks pass.
if (-not $ParameterMode) {
  cls
}

function Write-Section {
  param(
    [string]$Title
  )

  Write-Host ""
  Write-Host "============================================================" -ForegroundColor Cyan
  Write-Host $Title -ForegroundColor Cyan
  Write-Host "============================================================" -ForegroundColor Cyan
}

function Write-Ok {
  param([string]$Message)
  Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
  param([string]$Message)
  Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {
  param([string]$Message)
  Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-DefaultLine {
  param(
    [string]$Text
  )

  Write-Host $Text -ForegroundColor Yellow
}

function Format-CenteredText {
  param(
    [string]$Text,
    [int]$Width
  )

  if ($Text.Length -ge $Width) {
    return $Text.Substring(0, $Width)
  }

  $leftPadding = [Math]::Floor(($Width - $Text.Length) / 2)
  $rightPadding = $Width - $Text.Length - $leftPadding

  return ((" " * $leftPadding) + $Text + (" " * $rightPadding))
}

function Write-BoxLine {
  param(
    [string]$Text = "",
    [int]$Width = 72,
    [string]$ForegroundColor = "White"
  )

  $innerWidth = $Width - 4

  if ($Text.Length -gt $innerWidth) {
    $Text = $Text.Substring(0, $innerWidth)
  }

  $padding = " " * ($innerWidth - $Text.Length)
  Write-Host "| $Text$padding |" -ForegroundColor $ForegroundColor
}

function Show-IntroBanner {
  $width = 74
  $innerWidth = $width - 4

  Write-Host ""
  Write-Host ("+" + ("=" * ($width - 2)) + "+") -ForegroundColor Cyan
  Write-BoxLine -Text (Format-CenteredText -Text "MediaScribe" -Width $innerWidth) -Width $width -ForegroundColor Green
  Write-BoxLine -Text (Format-CenteredText -Text "Creates transcripts and caption files from audio/video files" -Width $innerWidth) -Width $width -ForegroundColor Yellow
  Write-Host ("+" + ("=" * ($width - 2)) + "+") -ForegroundColor Cyan
  Write-BoxLine -Width $width
  Write-BoxLine -Text "Transcribes local video and audio files into text and optional" -Width $width
  Write-BoxLine -Text "caption/subtitle files." -Width $width
  Write-BoxLine -Width $width
  Write-BoxLine -Text "Default output:" -Width $width -ForegroundColor Yellow
  Write-BoxLine -Text "  Original file, WAV audio, TXT transcript" -Width $width
  Write-BoxLine -Width $width
  Write-BoxLine -Text "Full output:" -Width $width -ForegroundColor Yellow
  Write-BoxLine -Text "  Original file, WAV audio, TXT, SRT, VTT, TSV, JSON" -Width $width
  Write-BoxLine -Width $width
  Write-BoxLine -Text "Caption use:" -Width $width -ForegroundColor Yellow
  Write-BoxLine -Text "  Use SRT or VTT files for video caption/subtitle workflows." -Width $width
  Write-BoxLine -Width $width
  Write-BoxLine -Text "Recognized video files:" -Width $width -ForegroundColor Yellow
  Write-BoxLine -Text "  MP4, MKV, MOV, M4V, AVI, WEBM" -Width $width
  Write-BoxLine -Width $width
  Write-BoxLine -Text "Recognized audio files:" -Width $width -ForegroundColor Yellow
  Write-BoxLine -Text "  MP3, M4A, WAV, AAC, FLAC, OGG, OPUS, WMA" -Width $width
  Write-BoxLine -Width $width
  Write-BoxLine -Text "Notes:" -Width $width -ForegroundColor Yellow
  Write-BoxLine -Text "  DRM/protected media may fail." -Width $width
  Write-BoxLine -Text "  Audio is extracted only and converted to mono 16 kHz WAV." -Width $width
  Write-Host ("+" + ("=" * ($width - 2)) + "+") -ForegroundColor Cyan
}

$VideoExtensions = @(".mp4", ".mkv", ".mov", ".m4v", ".avi", ".webm")
$AudioExtensions = @(".mp3", ".m4a", ".wav", ".aac", ".flac", ".ogg", ".opus", ".wma")
$SupportedExtensions = $VideoExtensions + $AudioExtensions
$ExtPattern = "\.({0})$" -f (($SupportedExtensions | ForEach-Object { $_.TrimStart(".") }) -join "|")

if (-not $ParameterMode) {
  Show-IntroBanner
  Write-Host ""
  Write-Host "Input folder:" -ForegroundColor Yellow
  Write-Host "  $InputDir" -ForegroundColor Green
  Write-Host ""
  Write-Host "Output folder:" -ForegroundColor Yellow
  Write-Host "  $OutputDir\<FileName>\" -ForegroundColor Green
  Write-Host ""

  Read-Host "Press Enter to start" | Out-Null
  cls
}

function Select-OutputMode {
  param(
    [string]$DefaultOutputMode
  )

  $defaultLabel = if ($DefaultOutputMode -eq "full") { "Full" } else { "Default" }

  Write-Host ""
  Write-Section "Output Options"
  Write-Host "  [D] Default - Original file, WAV audio, TXT transcript" -ForegroundColor Yellow
  Write-Host "  [F] Full    - Original file, WAV audio, TXT, SRT, VTT, TSV, JSON" -ForegroundColor Green
  Write-Host ""
  Write-DefaultLine "Default: $defaultLabel"
  $modeChoice = Read-Host "Output mode (D/F, default D)"

  if ([string]::IsNullOrWhiteSpace($modeChoice)) {
    return $DefaultOutputMode
  }

  switch ($modeChoice.Trim().ToUpper()) {
    "F" { return "full" }
    "FULL" { return "full" }
    default { return "default" }
  }
}

function Select-WhisperModel {
  param(
    [string]$DefaultModel
  )

  Write-Host ""
  Write-Section "Transcription Mode"
  Write-Host "  [F] Fast     - Uses configured/default model ($DefaultModel)" -ForegroundColor Yellow
  Write-Host "  [A] Accurate - Uses large model" -ForegroundColor Green
  Write-Host ""
  Write-DefaultLine "Default: Fast / $DefaultModel"
  $modeChoice = Read-Host "Mode (F/A, default F)"

  if ([string]::IsNullOrWhiteSpace($modeChoice)) {
    $modeChoice = "F"
  }

  if ($modeChoice.Trim().ToUpper() -eq "A") {
    return "large"
  }

  return $DefaultModel
}

function Invoke-TranscriptionFile {
  param(
    [System.IO.FileInfo]$SelectedInputFile,
    [string]$SelectedOutputMode,
    [string]$WhisperModel,
    [string]$WhisperLanguage,
    [string]$WhisperTask = "transcribe",
    [bool]$OpenFolderWhenDone = $false
  )

  $WhisperOutputFormat = if ($SelectedOutputMode -eq "full") { "all" } else { "txt" }

  $ResolvedInputDir = (Resolve-Path -LiteralPath $InputDir).ProviderPath
  $ResolvedInputDirWithSlash = $ResolvedInputDir.TrimEnd('\') + '\'
  $ResolvedInputFile = (Resolve-Path -LiteralPath $SelectedInputFile.FullName).ProviderPath
  $InputFileIsInsideInputFolder = $ResolvedInputFile.StartsWith($ResolvedInputDirWithSlash, [System.StringComparison]::OrdinalIgnoreCase)

  $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($SelectedInputFile.Name)
  $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"

  # Human-friendly default: first run uses the plain file name.
  $JobDir = Join-Path $OutputDir $BaseName

  # If folder already exists, create a timestamped sibling folder.
  if (Test-Path -LiteralPath $JobDir) {
    $JobDir = Join-Path $OutputDir ("{0}_{1}" -f $BaseName, $Stamp)
  }

  New-Item -ItemType Directory -Path $JobDir -Force | Out-Null

  Write-Section "Transcription Settings"
  Write-Info "Selected file: $($SelectedInputFile.Name)"
  Write-Info "Archive folder: $JobDir"
  Write-Info "Output mode: $SelectedOutputMode"
  Write-Info "Whisper model: $WhisperModel"

  $WhisperLanguage = Normalize-WhisperLanguage -LanguageValue $WhisperLanguage -FallbackLanguage "en"
  $WhisperTask = Normalize-WhisperTask -TaskValue $WhisperTask

  if ($WhisperLanguage -eq "auto") {
    Write-Info "Language: Auto-detect"
  } else {
    Write-Info "Language: $WhisperLanguage"
  }

  if ($WhisperTask -eq "translate") {
    Write-Info "Output text: English translation"
  } else {
    Write-Info "Output text: Same as input / detected"
  }

  # Create WAV in the job folder.
  $WavPath = Join-Path $JobDir "$BaseName.wav"

  Write-Section "Extracting Audio"
  Write-Info "FFmpeg output: $WavPath"

  # -vn = ignore video; safe for audio-only inputs too.
  # Start FFmpeg as a child process instead of piping output through PowerShell.
  $ffmpegArgs = @(
    "-hide_banner",
    "-loglevel", "error",
    "-i", "`"$($SelectedInputFile.FullName)`"",
    "-vn",
    "-ac", "1",
    "-ar", "16000",
    "-c:a", "pcm_s16le",
    "`"$WavPath`"",
    "-y"
  )

  $ffmpegProcess = Start-Process -FilePath $ResolvedFFmpegCommand.FilePath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
  $ffmpegExit = $ffmpegProcess.ExitCode

  if ($ffmpegExit -ne 0) {
    Write-Warn "FFmpeg exited with code $ffmpegExit"
  }

  if (-not (Test-Path -LiteralPath $WavPath)) {
    Write-Host "Failed to create WAV file. DRM/protected media or unsupported codec may be the cause."
    Write-Host "Install or update FFmpeg, then retry."

    return [pscustomobject]@{
      FileName = $SelectedInputFile.Name
      JobDir   = $JobDir
      ExitCode = 1
      Success  = $false
      Message  = "WAV creation failed"
    }
  }

  # Run Whisper before moving the original input file.
  # This keeps the source path stable while FFmpeg and Whisper are working.
  Write-Section "Transcribing"
  Write-Info "Running Whisper model: $WhisperModel"

  if ($WhisperLanguage -eq "auto") {
    Write-Info "Whisper language: Auto-detect"
  } else {
    Write-Info "Whisper language: $WhisperLanguage"
  }

  if ($WhisperTask -eq "translate") {
    Write-Info "Whisper task: Translate to English"
  } else {
    Write-Info "Whisper task: Transcribe"
  }

  # Live preview is enabled only for English transcription.
  # Auto-detect, non-English input, and English translation are run quietly so Windows does not crash
  # while trying to display characters that may not be supported by the status window.
  $ShowLivePreview = ($WhisperLanguage -eq "en" -and $WhisperTask -eq "transcribe")

  if ($ShowLivePreview) {
    Write-Info "Live transcript progress appears in 30-second chunks."
    Write-Info "Progress is displayed below and may take a while."
  } else {
    Write-Warn "Live transcript preview is not shown for this language/output setting."
    Write-Info "Some characters may not display correctly in the Windows status window."
    Write-Info "English translation and non-English transcription still create the final transcript file."
  }

  Write-Host ""

  # Encourage Python/Whisper to use UTF-8 where possible.
  $env:PYTHONIOENCODING = "utf-8"
  $env:PYTHONUTF8 = "1"

  try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
  } catch {
    # Ignore encoding setup errors.
  }

  if ($ResolvedWhisperCommand.Mode -eq "PythonModule") {
    $whisperArgs = @(
      "-m", "whisper",
      "`"$WavPath`"",
      "--model", $WhisperModel,
      "--fp16", "False",
      "--task", $WhisperTask,
      "--output_dir", "`"$JobDir`"",
      "--output_format", $WhisperOutputFormat
    )
  } else {
    $whisperArgs = @(
      "`"$WavPath`"",
      "--model", $WhisperModel,
      "--fp16", "False",
      "--task", $WhisperTask,
      "--output_dir", "`"$JobDir`"",
      "--output_format", $WhisperOutputFormat
    )
  }

  if ($WhisperLanguage -ne "auto") {
    $whisperArgs += @("--language", $WhisperLanguage)
  }

  if (-not $ShowLivePreview) {
    $whisperArgs += @("--verbose", "False")
  }

  $whisperStdOutLog = Join-Path $JobDir "whisper_stdout.log"
  $whisperStdErrLog = Join-Path $JobDir "whisper_stderr.log"

  $previousTqdmDisable = $env:TQDM_DISABLE

  try {
    Write-Info "Whisper command source: $($ResolvedWhisperCommand.Source)"
    Write-Info "Whisper executable: $($ResolvedWhisperCommand.FilePath)"

    if ($ShowLivePreview) {
      $whisperProcess = Start-Process `
        -FilePath $ResolvedWhisperCommand.FilePath `
        -ArgumentList $whisperArgs `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -ErrorAction Stop
    } else {
      Write-Info "Whisper progress output is hidden for this language setting."
      Write-Info "Whisper log files will be saved in the job folder if needed."

      $env:TQDM_DISABLE = "1"

      $whisperProcess = Start-Process `
        -FilePath $ResolvedWhisperCommand.FilePath `
        -ArgumentList $whisperArgs `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $whisperStdOutLog `
        -RedirectStandardError $whisperStdErrLog `
        -ErrorAction Stop
    }

    if ($null -eq $previousTqdmDisable) {
      Remove-Item Env:\TQDM_DISABLE -ErrorAction SilentlyContinue
    } else {
      $env:TQDM_DISABLE = $previousTqdmDisable
    }

    $whisperExit = $whisperProcess.ExitCode
  } catch {
    if ($null -eq $previousTqdmDisable) {
      Remove-Item Env:\TQDM_DISABLE -ErrorAction SilentlyContinue
    } else {
      $env:TQDM_DISABLE = $previousTqdmDisable
    }

    Write-ErrorMessage "Whisper could not be started."
    Write-ErrorMessage $_.Exception.Message
    Write-Warn "Audio extraction succeeded, so the WAV file may still be usable:"
    Write-Host "  $WavPath"

    return [pscustomobject]@{
      FileName = $SelectedInputFile.Name
      JobDir   = $JobDir
      ExitCode = 1
      Success  = $false
      Message  = "Whisper could not be started: $($_.Exception.Message)"
    }
  }

  $expectedExtensions = Get-ExpectedOutputExtensions -SelectedOutputMode $SelectedOutputMode
  $missingOutputs = @()

  foreach ($extension in $expectedExtensions) {
    $expectedPath = Join-Path $JobDir "$BaseName$extension"

    if (-not (Test-Path -LiteralPath $expectedPath)) {
      $missingOutputs += $extension
    }
  }

  $outputsCreated = ($missingOutputs.Count -eq 0)

  if ($whisperExit -eq 0 -and -not $outputsCreated) {
    Write-Warn "Whisper finished, but expected output files were not found: $($missingOutputs -join ', ')."
  }

  # Archive original input file only after transcription really completes.
  if ($whisperExit -eq 0 -and $outputsCreated) {
    $archivedOriginal = Get-UniqueDestinationPath -FolderPath $JobDir -FileName $SelectedInputFile.Name

    if ($InputFileIsInsideInputFolder -and $MoveInputFolderFilesAfterProcessing) {
      Write-Info "Input file is inside the Input folder; moving original into job folder."
      Move-Item -LiteralPath $SelectedInputFile.FullName -Destination $archivedOriginal -Force
    } elseif (-not $InputFileIsInsideInputFolder) {
      if ($ExternalFileArchiveBehavior -eq "CopyToJobFolder") {
        Write-Info "External input file detected; original file will be copied into job folder."
        Copy-Item -LiteralPath $SelectedInputFile.FullName -Destination $archivedOriginal -Force
      } elseif ($ExternalFileArchiveBehavior -eq "LeaveOriginalInPlace") {
        Write-Info "External input file detected; original file will be left in place."
      } else {
        Write-Info "External input file detected; original file is outside the Input folder; leaving original in place."
        Write-Warn "ExternalFileArchiveBehavior is set to '$ExternalFileArchiveBehavior'; only LeaveOriginalInPlace is currently supported."
      }
    }
  }

  Write-Host ""

  if ($whisperExit -eq 0 -and $outputsCreated) {
    Write-Section "Complete"
    Write-Ok "Done. Files saved in:"
    Write-Host "  $JobDir"
  } else {
    Write-Section "Complete"
    Write-Warn "Whisper did not create the expected transcript output."
    Write-Host "Check output folder:"
    Write-Host "  $JobDir"
  }

  if ($OpenFolderWhenDone) {
    Start-Process explorer.exe "$JobDir"
  }

  return [pscustomobject]@{
    FileName = $SelectedInputFile.Name
    JobDir   = $JobDir
    ExitCode = if ($whisperExit -eq 0 -and $missingOutputs.Count -gt 0) { 1 } else { $whisperExit }
    Success  = ($whisperExit -eq 0 -and $missingOutputs.Count -eq 0)
    Message  = if ($missingOutputs.Count -gt 0) {
      "Missing expected output files: $($missingOutputs -join ', ')"
    } elseif ($whisperExit -ne 0) {
      "Whisper exited with code $whisperExit"
    } else {
      "OK"
    }
  }
}

if ($ParameterMode) {
  if (-not (Test-Path -LiteralPath $InputFile)) {
    Write-Host "Input file was not found:"
    Write-Host "  $InputFile"
    exit 1
  }

  $SelectedOutputMode = $NormalizedOutputMode

  $result = Invoke-TranscriptionFile `
    -SelectedInputFile (Get-Item -LiteralPath $InputFile) `
    -SelectedOutputMode $SelectedOutputMode `
    -WhisperModel $DefaultModel `
    -WhisperLanguage $DefaultLanguage `
    -WhisperTask $WhisperTask `
    -OpenFolderWhenDone:$false

  exit $result.ExitCode
}

:InteractiveLoop do {
  # Find input media files.
  $mediaFiles = Get-ChildItem $InputDir -File |
    Where-Object { $_.Extension -match $ExtPattern } |
    Sort-Object Name

  if (-not $mediaFiles -or $mediaFiles.Count -eq 0) {
    Write-Section "Input Folder"
    Write-Warn "No recognized media files found in:"
    Write-Host "  $InputDir"
    Write-Host ""
    Write-Info "Recognized formats:"
    Write-Host "  mp4 mkv mov m4v avi webm | mp3 m4a wav aac flac ogg opus wma"
    Write-Host ""
    Write-Host "What would you like to do?"
    Write-Host "  [R] Refresh / check again" -ForegroundColor Yellow
    Write-Host "  [O] Open Input folder" -ForegroundColor Yellow
    Write-Host "  [Q] Quit" -ForegroundColor Yellow

    $noFilesChoice = Read-Host "Choice (R/O/Q, default R)"
    $noFilesChoice = $noFilesChoice.Trim().ToUpper()

    if ([string]::IsNullOrWhiteSpace($noFilesChoice) -or $noFilesChoice -eq "R" -or $noFilesChoice -eq "REFRESH") {
      continue InteractiveLoop
    }

    if ($noFilesChoice -eq "O" -or $noFilesChoice -eq "OPEN") {
      Start-Process explorer.exe "$InputDir"
      continue InteractiveLoop
    }

    if ($noFilesChoice -in @("Q", "QUIT", "E", "EXIT")) {
      exit
    }

    Write-Warn "Invalid selection. Refreshing file list."
    continue InteractiveLoop
  }

  Write-Section "Recognized Files"
  Write-Host "Recognized files found:" -ForegroundColor Yellow

  for ($i = 0; $i -lt $mediaFiles.Count; $i++) {
    Write-Host "  [$($i + 1)] $($mediaFiles[$i].Name)" -ForegroundColor Yellow
  }

  if ($mediaFiles.Count -gt 1) {
    Write-Host "  [B] Process all files" -ForegroundColor Yellow
  }

  Write-Host "  [Q] Quit" -ForegroundColor Yellow

  $choice = Read-Host "Choose file number, B for all, or Q to quit"
  $trimmedChoice = $choice.Trim().ToUpper()

  if ($trimmedChoice -in @("Q", "QUIT", "E", "EXIT")) {
    exit
  }

  $batchMode = $false

  if ($trimmedChoice -eq "B") {
    if ($mediaFiles.Count -le 1) {
      Write-Warn "Batch mode requires more than one recognized file."
      Pause
      continue
    }

    $selectedFiles = @($mediaFiles)
    $batchMode = $true
  } elseif ($trimmedChoice -match '^\d+$') {
    $index = [int]$trimmedChoice - 1

    if ($index -lt 0 -or $index -ge $mediaFiles.Count) {
      Write-Host "Invalid file number." -ForegroundColor Yellow
      Pause
      continue
    }

    $selectedFiles = @($mediaFiles[$index])
  } else {
    Write-Host "Invalid selection." -ForegroundColor Yellow
    Pause
    continue
  }

  if (-not $selectedFiles -or $selectedFiles.Count -eq 0) {
    Write-Warn "No files selected. Refreshing file list."
    continue
  }

  $SelectedOutputMode = Select-OutputMode -DefaultOutputMode $NormalizedOutputMode
  Write-Info "Output mode selected: $SelectedOutputMode"

  $WhisperModel = Select-WhisperModel -DefaultModel $DefaultModel
  $WhisperLanguage = $DefaultLanguage

  cls

  if ($batchMode) {
    Write-Section "Batch Settings"
    Write-Info "Files selected: $($selectedFiles.Count)"
    Write-Info "Output mode: $SelectedOutputMode"
    Write-Info "Whisper model: $WhisperModel"

    if ($WhisperLanguage -eq "auto") {
      Write-Info "Language: Auto-detect"
    } else {
      Write-Info "Language: $WhisperLanguage"
    }

    if ($WhisperTask -eq "translate") {
      Write-Info "Output text: English translation"
    } else {
      Write-Info "Output text: Same as input / detected"
    }
  }

  $results = @()

  for ($i = 0; $i -lt $selectedFiles.Count; $i++) {
    $currentFile = $selectedFiles[$i]

    if ($batchMode) {
      Write-Section "Batch Item $($i + 1) of $($selectedFiles.Count)"
      Write-Info "File: $($currentFile.Name)"
    }

    $result = Invoke-TranscriptionFile `
      -SelectedInputFile $currentFile `
      -SelectedOutputMode $SelectedOutputMode `
      -WhisperModel $WhisperModel `
      -WhisperLanguage $WhisperLanguage `
      -WhisperTask $WhisperTask `
      -OpenFolderWhenDone:$false

    $results += $result
  }

  if ($batchMode) {
    Write-Section "Batch Summary"

    foreach ($result in $results) {
      if ($result.Success) {
        Write-Ok "$($result.FileName)"
      } else {
        Write-Warn "$($result.FileName) - $($result.Message)"
      }
    }

    Write-Host ""
    Write-Host "Output folder:"
    Write-Host "  $OutputDir"
  }

  $nextOpenTarget = if ($batchMode) { $OutputDir } else { $results[0].JobDir }

  Write-Section "Next Step"
  Write-Ok "Processing complete."
  Write-Host ""
  Write-Host "What would you like to do next?"
  Write-Host "  [R] Run again / return to file list" -ForegroundColor Yellow
  Write-Host "  [O] Open output folder" -ForegroundColor Yellow
  Write-Host "  [Q] Quit" -ForegroundColor Yellow

  $nextChoice = Read-Host "Choice (R/O/Q, default Q)"
  $nextChoice = $nextChoice.Trim().ToUpper()

  if ($nextChoice -eq "R" -or $nextChoice -eq "RUN" -or $nextChoice -eq "AGAIN") {
    continue InteractiveLoop
  }

  if ($nextChoice -eq "O" -or $nextChoice -eq "OPEN") {
    Start-Process explorer.exe "$nextOpenTarget"
    exit
  }

  if ([string]::IsNullOrWhiteSpace($nextChoice) -or $nextChoice -in @("Q", "QUIT", "E", "EXIT")) {
    exit
  }

  Write-Warn "Invalid selection. Exiting."
  exit
} while ($true)