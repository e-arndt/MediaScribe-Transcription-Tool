# =====================================================
# Transcribe.ps1 - Archive-style transcription workflow
# Configuration is loaded from config.json next to this script.
# =====================================================

param(
  [string]$InputFile,
  [string]$OutputFolder,
  [string]$Model,
  [string]$Language
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

$ConfigPath = Join-Path $PSScriptRoot "config.json"
$DefaultConfig = New-DefaultConfig

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  $DefaultConfig | ConvertTo-Json -Depth 4 | Set-Content -Path $ConfigPath -Encoding UTF8
}

try {
  $Config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
} catch {
  Write-Host "Could not read config.json. Please fix or delete it, then run again." -ForegroundColor Red
  Write-Host "Config path: $ConfigPath"
  exit 1
}

$AppName = [string](Get-ConfigValue -Config $Config -Name "AppName" -DefaultValue $DefaultConfig.AppName)

$BaseDirRaw = [string](Get-ConfigValue -Config $Config -Name "BaseFolder" -DefaultValue $DefaultConfig.BaseFolder)
$BaseDir = Resolve-ConfiguredPath -PathValue $BaseDirRaw -BaseFolder $PSScriptRoot

$InputDirRaw = [string](Get-ConfigValue -Config $Config -Name "InputFolder" -DefaultValue (Join-Path $BaseDir "Input"))
$OutputDirRaw = [string](Get-ConfigValue -Config $Config -Name "OutputFolder" -DefaultValue (Join-Path $BaseDir "Output"))
$LogsDirRaw = [string](Get-ConfigValue -Config $Config -Name "LogsFolder" -DefaultValue (Join-Path $BaseDir "Logs"))
$ModelsDirRaw = [string](Get-ConfigValue -Config $Config -Name "ModelsFolder" -DefaultValue (Join-Path $BaseDir "Models"))

$InputDir = Resolve-ConfiguredPath -PathValue $InputDirRaw -BaseFolder $BaseDir
$OutputDir = Resolve-ConfiguredPath -PathValue $OutputDirRaw -BaseFolder $BaseDir
$LogsDir = Resolve-ConfiguredPath -PathValue $LogsDirRaw -BaseFolder $BaseDir
$ModelsDir = Resolve-ConfiguredPath -PathValue $ModelsDirRaw -BaseFolder $BaseDir

$DefaultModel = [string](Get-ConfigValue -Config $Config -Name "DefaultModel" -DefaultValue $DefaultConfig.DefaultModel)
$DefaultLanguage = [string](Get-ConfigValue -Config $Config -Name "DefaultLanguage" -DefaultValue $DefaultConfig.DefaultLanguage)
$ConfiguredOutputMode = [string](Get-ConfigValue -Config $Config -Name "OutputMode" -DefaultValue $DefaultConfig.OutputMode)
$MoveInputFolderFilesAfterProcessing = [bool](Get-ConfigValue -Config $Config -Name "MoveInputFolderFilesAfterProcessing" -DefaultValue $DefaultConfig.MoveInputFolderFilesAfterProcessing)
$ExternalFileArchiveBehavior = [string](Get-ConfigValue -Config $Config -Name "ExternalFileArchiveBehavior" -DefaultValue $DefaultConfig.ExternalFileArchiveBehavior)

$NormalizedOutputMode = $ConfiguredOutputMode.Trim().ToLowerInvariant()
if ($NormalizedOutputMode -notin @("default", "full")) {
  Write-Host "Invalid OutputMode in config.json: $ConfiguredOutputMode" -ForegroundColor Yellow
  Write-Host "Using OutputMode: default"
  $NormalizedOutputMode = "default"
}

if (-not [string]::IsNullOrWhiteSpace($OutputFolder)) {
  $OutputDir = $OutputFolder
}

$ParameterMode = -not [string]::IsNullOrWhiteSpace($InputFile)

# --- Recognized formats (edit this list if you want more) ---
$ExtPattern = '\.(mp4|mkv|mov|m4v|avi|webm|mp3|m4a|wav|aac|flac|ogg|opus|wma)$'

# Ensure folders exist
foreach ($folder in @($InputDir, $OutputDir, $LogsDir, $ModelsDir)) {
  New-Item -ItemType Directory -Path $folder -Force | Out-Null
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
    [int]$Width = 70
  )

  if ($Text.Length -gt $Width) {
    $Text = $Text.Substring(0, $Width)
  }

  Write-Host ("| " + $Text + (" " * ($Width - $Text.Length)) + " |")
}

if (-not $ParameterMode) {
  $bannerWidth = 70
  $bannerBorder = "+" + ("=" * ($bannerWidth + 2)) + "+"

  Write-Host ""
  Write-Host $bannerBorder
  Write-BoxLine -Text (Format-CenteredText -Text $AppName -Width $bannerWidth) -Width $bannerWidth
  Write-BoxLine -Text (Format-CenteredText -Text "Creates transcripts and caption files from audio/video files" -Width $bannerWidth) -Width $bannerWidth
  Write-Host $bannerBorder
  Write-BoxLine -Width $bannerWidth
  Write-BoxLine -Text "Transcribes local video and audio files into text and optional" -Width $bannerWidth
  Write-BoxLine -Text "caption/subtitle files." -Width $bannerWidth
  Write-BoxLine -Width $bannerWidth
  Write-BoxLine -Text "Default output:" -Width $bannerWidth
  Write-BoxLine -Text "  Original file, WAV audio, TXT transcript" -Width $bannerWidth
  Write-BoxLine -Width $bannerWidth
  Write-BoxLine -Text "Full output:" -Width $bannerWidth
  Write-BoxLine -Text "  Original file, WAV audio, TXT, SRT, VTT, TSV, JSON" -Width $bannerWidth
  Write-BoxLine -Width $bannerWidth
  Write-BoxLine -Text "Caption use:" -Width $bannerWidth
  Write-BoxLine -Text "  Use SRT or VTT files for video caption/subtitle workflows." -Width $bannerWidth
  Write-BoxLine -Width $bannerWidth
  Write-BoxLine -Text "Recognized video files:" -Width $bannerWidth
  Write-BoxLine -Text "  MP4, MKV, MOV, M4V, AVI, WEBM" -Width $bannerWidth
  Write-BoxLine -Width $bannerWidth
  Write-BoxLine -Text "Recognized audio files:" -Width $bannerWidth
  Write-BoxLine -Text "  MP3, M4A, WAV, AAC, FLAC, OGG, OPUS, WMA" -Width $bannerWidth
  Write-BoxLine -Width $bannerWidth
  Write-BoxLine -Text "Notes:" -Width $bannerWidth
  Write-BoxLine -Text "  DRM/protected media may fail." -Width $bannerWidth
  Write-BoxLine -Text "  Audio is extracted only and converted to mono 16 kHz WAV." -Width $bannerWidth
  Write-Host $bannerBorder
  Write-Host ""
  Write-Host "Input folder:"
  Write-Host "  $InputDir"
  Write-Host ""
  Write-Host "Output folder:"
  Write-Host "  $OutputDir\<FileName>\"
  Write-Host ""
  Read-Host "Press Enter to start (Ctrl+C to cancel)" | Out-Null
}

function Select-OutputMode {
  param(
    [string]$DefaultOutputMode
  )

  Write-Host ""
  Write-Host "Select output files:"
  Write-Host "  [D] Default - original file, WAV, TXT transcript"
  Write-Host "  [F] Full    - original file, WAV, TXT, SRT, VTT, TSV, JSON"

  $defaultOutputChoice = if ($DefaultOutputMode -eq "full") { "F" } else { "D" }
  $outputChoice = Read-Host "Output mode (D/F, default $defaultOutputChoice)"

  if ([string]::IsNullOrWhiteSpace($outputChoice)) {
    $outputChoice = $defaultOutputChoice
  }

  switch ($outputChoice.Trim().ToUpper()) {
    "F" {
      return "full"
    }
    "D" {
      return "default"
    }
    default {
      Write-Host "Invalid output selection. Using config/default output mode: $DefaultOutputMode" -ForegroundColor Yellow
      return $DefaultOutputMode
    }
  }
}

function Select-WhisperModel {
  param(
    [string]$DefaultModel
  )

  Write-Host ""
  Write-Host "Select mode:"
  Write-Host "  [F] Fast (default) - quicker; good for most audio"
  Write-Host "  [A] Accurate - slower; better if Fast misses words; more compute / larger model"
  $modeChoice = Read-Host "Mode (F/A)"

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
    [bool]$OpenFolderWhenDone = $false
  )

  $WhisperOutputFormat = if ($SelectedOutputMode -eq "full") { "all" } else { "txt" }

  $ResolvedInputDir = (Resolve-Path -LiteralPath $InputDir).ProviderPath
  $ResolvedInputDirWithSeparator = $ResolvedInputDir.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
  $ResolvedSelectedInputPath = (Resolve-Path -LiteralPath $SelectedInputFile.FullName).ProviderPath
  $SelectedFileIsInInputDir = $ResolvedSelectedInputPath.StartsWith($ResolvedInputDirWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)

  $BaseName = $SelectedInputFile.BaseName
  $Stamp    = (Get-Date).ToString("yyyyMMdd_HHmmss")

  # Job folder = archive folder for this input
  $JobDir = Join-Path $OutputDir $BaseName

  # If folder already exists, create a timestamped sibling folder
  if (Test-Path -LiteralPath $JobDir) {
    $JobDir = Join-Path $OutputDir ("{0}_{1}" -f $BaseName, $Stamp)
  }

  New-Item -ItemType Directory -Path $JobDir -Force | Out-Null

  Write-Host ""
  Write-Host "Selected file: $($SelectedInputFile.Name)"
  Write-Host "Archive folder: $JobDir"
  Write-Host "Output mode: $SelectedOutputMode"

  # Create WAV in the job folder (archive artifact)
  $WavPath = Join-Path $JobDir "$BaseName.wav"

  Write-Host ""
  Write-Host "Extracting audio (FFmpeg) -> $WavPath"
  # -vn = ignore video; safe for audio-only inputs too.
  # Start FFmpeg as a child process instead of piping output through PowerShell.
  # This keeps console feedback more consistent in batch mode and prevents
  # native-process output from becoming part of this function's return value.
  $ffmpegArgs = @(
    "-i", "`"$($SelectedInputFile.FullName)`"",
    "-vn",
    "-ac", "1",
    "-ar", "16000",
    "-c:a", "pcm_s16le",
    "`"$WavPath`"",
    "-y"
  )
  $ffmpegProcess = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
  $ffmpegExit = $ffmpegProcess.ExitCode

  if ($ffmpegExit -ne 0) {
    Write-Host "⚠️ FFmpeg exited with code $ffmpegExit" -ForegroundColor Yellow
  }

  if (-not (Test-Path -LiteralPath $WavPath)) {
    Write-Host "Failed to create WAV file. DRM/protected media or unsupported codec may be the cause." -ForegroundColor Red
    Write-Host "Try re-encoding the source file first, then retry."

    return [pscustomobject]@{
      FileName = $SelectedInputFile.Name
      JobDir = $JobDir
      ExitCode = 1
      Success = $false
      Message = "WAV creation failed"
    }
  }

  # Run Whisper before moving the original input file.
  # This keeps the source path stable while FFmpeg and Whisper are working.
  Write-Host ""
  Write-Host "Running Whisper ($WhisperModel)..."
  # Start Whisper as a child process instead of piping output through PowerShell.
  # This keeps each batch item visually separate and avoids buffering/capturing
  # transcript lines into the batch result collection.
  $whisperArgs = @(
    "-m", "whisper",
    "`"$WavPath`"",
    "--model", $WhisperModel,
    "--language", $WhisperLanguage,
    "--output_dir", "`"$JobDir`"",
    "--output_format", $WhisperOutputFormat
  )
  $whisperProcess = Start-Process -FilePath "python" -ArgumentList $whisperArgs -NoNewWindow -Wait -PassThru
  $whisperExit = $whisperProcess.ExitCode

  # Verify expected outputs exist.
  # Default mode expects only the plain text transcript from Whisper.
  # Full mode expects all common Whisper sidecar formats.
  $expectedOutputExtensions = if ($SelectedOutputMode -eq "full") {
    @(".txt", ".srt", ".vtt", ".tsv", ".json")
  } else {
    @(".txt")
  }

  $missingOutputs = @()
  foreach ($extension in $expectedOutputExtensions) {
    $expectedPath = Join-Path $JobDir "$BaseName$extension"
    if (-not (Test-Path -LiteralPath $expectedPath)) {
      $missingOutputs += $extension
    }
  }

  if ($missingOutputs.Count -gt 0) {
    Write-Host "⚠️ Whisper finished, but expected output files were not found: $($missingOutputs -join ', ')." -ForegroundColor Yellow
  }

  Write-Host ""
  if ($SelectedFileIsInInputDir -and $MoveInputFolderFilesAfterProcessing) {
    Write-Host "Input file is inside the Input folder; moving original into job folder."
    $ArchivedInputPath = Join-Path $JobDir $SelectedInputFile.Name

    if (Test-Path -LiteralPath $ArchivedInputPath) {
      # Extremely rare (same filename already in this new folder). Add timestamp to the file name.
      $nameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($SelectedInputFile.Name)
      $ext       = [System.IO.Path]::GetExtension($SelectedInputFile.Name)
      $ArchivedInputPath = Join-Path $JobDir ("{0}_{1}{2}" -f $nameNoExt, $Stamp, $ext)
    }

    try {
      Move-Item -LiteralPath $SelectedInputFile.FullName -Destination $ArchivedInputPath -ErrorAction Stop
    } catch {
      Write-Host "⚠️ Could not move original input file into the job folder." -ForegroundColor Yellow
      Write-Host "Source remains at:"
      Write-Host "  $($SelectedInputFile.FullName)"
      Write-Host "Move error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
  } elseif ($SelectedFileIsInInputDir -and -not $MoveInputFolderFilesAfterProcessing) {
    Write-Host "Input file is inside the Input folder; leaving original in place because config disables moving."
  } else {
    switch ($ExternalFileArchiveBehavior.Trim()) {
      "LeaveOriginalInPlace" {
        Write-Host "Input file is outside the Input folder; leaving original in place."
    }
    default {
      Write-Host "Input file is outside the Input folder; leaving original in place."
      Write-Host "ExternalFileArchiveBehavior is set to '$ExternalFileArchiveBehavior'; only LeaveOriginalInPlace is currently supported." -ForegroundColor Yellow
    }
  }
}

  Write-Host ""
  if ($whisperExit -eq 0) {
    Write-Host "✅ Done. Files saved in:"
    Write-Host "  $JobDir"
  } else {
    Write-Host "⚠️ Whisper exited with code $whisperExit" -ForegroundColor Yellow
    Write-Host "Check output folder:"
    Write-Host "  $JobDir"
  }

  if ($OpenFolderWhenDone) {
    Start-Process explorer.exe "$JobDir"
  }

  return [pscustomobject]@{
    FileName = $SelectedInputFile.Name
    JobDir = $JobDir
    ExitCode = $whisperExit
    Success = ($whisperExit -eq 0 -and $missingOutputs.Count -eq 0)
    Message = if ($missingOutputs.Count -gt 0) { "Missing expected output files: $($missingOutputs -join ', ')" } elseif ($whisperExit -ne 0) { "Whisper exited with code $whisperExit" } else { "OK" }
  }
}

if ($ParameterMode) {
  if (-not (Test-Path -LiteralPath $InputFile -PathType Leaf)) {
    Write-Host "Input file not found: $InputFile" -ForegroundColor Red
    exit 1
  }

  $SelectedInputFile = Get-Item -LiteralPath $InputFile
  if ($SelectedInputFile.Extension -notmatch $ExtPattern) {
    Write-Host "Input file type is not recognized: $($SelectedInputFile.Name)" -ForegroundColor Red
    exit 1
  }

  $WhisperModel = if ([string]::IsNullOrWhiteSpace($Model)) { $DefaultModel } else { $Model }
  $WhisperLanguage = if ([string]::IsNullOrWhiteSpace($Language)) { $DefaultLanguage } else { $Language }

  $result = Invoke-TranscriptionFile `
    -SelectedInputFile $SelectedInputFile `
    -SelectedOutputMode $NormalizedOutputMode `
    -WhisperModel $WhisperModel `
    -WhisperLanguage $WhisperLanguage `
    -OpenFolderWhenDone:$false

  exit $result.ExitCode
}

:InteractiveLoop do {
  # Find input media files (recognized extensions only)
  $mediaFiles = Get-ChildItem $InputDir -File |
    Where-Object { $_.Extension -match $ExtPattern } |
    Sort-Object Name

  if (-not $mediaFiles -or $mediaFiles.Count -eq 0) {
    Write-Host ""
    Write-Host "No recognized media files found in:" -ForegroundColor Yellow
    Write-Host "  $InputDir"
    Write-Host ""
    Write-Host "Recognized formats:"
    Write-Host "  mp4 mkv mov m4v avi webm | mp3 m4a wav aac flac ogg opus wma"
    Write-Host ""
    Write-Host "What would you like to do?"
    Write-Host "  [R] Refresh / check again"
    Write-Host "  [O] Open Input folder"
    Write-Host "  [Q] Quit"
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

    Write-Host "Invalid selection. Refreshing file list." -ForegroundColor Yellow
    continue InteractiveLoop
  }

  Write-Host ""
  Write-Host "Recognized files found:"
  for ($i = 0; $i -lt $mediaFiles.Count; $i++) {
    Write-Host "  [$($i + 1)] $($mediaFiles[$i].Name)"
  }

  if ($mediaFiles.Count -gt 1) {
    Write-Host "  [B] Process all files"
  }

  Write-Host "  [Q] Quit"

  $choice = Read-Host "Choose file number, B for all, or Q to quit"
  $trimmedChoice = $choice.Trim().ToUpper()

  if ($trimmedChoice -in @("Q", "QUIT", "E", "EXIT")) {
    exit
  }

  $batchMode = $false
  if ($trimmedChoice -eq "B") {
    if ($mediaFiles.Count -le 1) {
      Write-Host "Batch mode requires more than one recognized file." -ForegroundColor Yellow
      Pause
      continue
    }

    $selectedFiles = @($mediaFiles)
    $batchMode = $true
  } elseif ($trimmedChoice -match '^\d+$') {
    $selectedNumber = [int]$trimmedChoice
    if ($selectedNumber -lt 1 -or $selectedNumber -gt $mediaFiles.Count) {
      Write-Host "Invalid selection." -ForegroundColor Red
      Pause
      continue
    }

    $selectedFiles = @($mediaFiles[$selectedNumber - 1])
  } else {
    Write-Host "Invalid selection." -ForegroundColor Red
    Pause
    continue
  }

  $SelectedOutputMode = Select-OutputMode -DefaultOutputMode $NormalizedOutputMode
  Write-Host "Output mode: $SelectedOutputMode"

  $WhisperModel = Select-WhisperModel -DefaultModel $DefaultModel
  $WhisperLanguage = $DefaultLanguage

  if ($batchMode) {
    Write-Host ""
    Write-Host "Batch mode selected. Processing $($selectedFiles.Count) files."
    Write-Host "Output mode: $SelectedOutputMode"
    Write-Host "Whisper model: $WhisperModel"
    Write-Host ""
  }

  $results = @()
  for ($i = 0; $i -lt $selectedFiles.Count; $i++) {
    $currentFile = $selectedFiles[$i]

    if ($batchMode) {
      Write-Host ""
      Write-Host "====================================================="
      Write-Host "Batch item $($i + 1) of $($selectedFiles.Count): $($currentFile.Name)"
      Write-Host "====================================================="
    }

    $result = Invoke-TranscriptionFile `
      -SelectedInputFile $currentFile `
      -SelectedOutputMode $SelectedOutputMode `
      -WhisperModel $WhisperModel `
      -WhisperLanguage $WhisperLanguage `
      -OpenFolderWhenDone:$false

    $results += $result
  }

  if ($batchMode) {
    Write-Host ""
    Write-Host "Batch complete."
    Write-Host ""

    foreach ($result in $results) {
      if ($result.Success) {
        Write-Host "  ✅ $($result.FileName)"
      } else {
        Write-Host "  ⚠️ $($result.FileName) - $($result.Message)" -ForegroundColor Yellow
      }
    }

    Write-Host ""
    Write-Host "Output folder:"
    Write-Host "  $OutputDir"
  }

  $nextOpenTarget = if ($batchMode) { $OutputDir } else { $results[0].JobDir }

  Write-Host ""
  Write-Host "Processing complete."
  Write-Host ""
  Write-Host "What would you like to do next?"
  Write-Host "  [R] Run again / return to file list"
  Write-Host "  [O] Open output folder"
  Write-Host "  [Q] Quit"
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

  Write-Host "Invalid selection. Exiting." -ForegroundColor Yellow
  exit

} while ($true)
