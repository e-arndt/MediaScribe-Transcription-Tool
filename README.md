# MediaScribe

MediaScribe is a PowerShell-based transcription and caption-file tool for local audio and video files.

It uses FFmpeg to extract audio and Whisper to create transcripts and optional caption/subtitle outputs.

MediaScribe is designed around a simple folder workflow:

- Put files into `Input`
- Run `transcribe.ps1`
- Get results in `Output`

## What MediaScribe Creates

MediaScribe creates transcripts and caption files from audio/video files.

### Default Output

Default mode creates:

```text
Original file
WAV audio
TXT transcript
```

This is recommended for most users.

### Full Output

Full mode creates:

```text
Original file
WAV audio
TXT transcript
SRT subtitle file
VTT subtitle file
TSV timing file
JSON Whisper output
```

Use Full mode when subtitle/caption files or detailed Whisper output are needed.

### Caption Use

Use `SRT` or `VTT` files for video caption/subtitle workflows.

## Current Status

This is currently the PowerShell engine version of the project.

Planned future improvements may include:

- Setup script
- Simple GUI launcher
- More polished desktop app or installer

## Project Folders

```text
MediaScribe/
  Input/
  Output/
  Logs/
  Models/
  config.json
  transcribe.ps1
  README.md
  How to Start transcription.txt
```

## Folder Purpose

### Input

Put supported audio or video files here before running the script.

### Output

Transcription results are saved here.

Each processed file gets its own output folder.

Example:

```text
Output/
  My Recording/
    My Recording.mp3
    My Recording.wav
    My Recording.txt
```

### Logs

Reserved for future logging support.

### Models

Reserved for future model-related support.

## Supported Input Formats

Recognized video files:

```text
MP4, MKV, MOV, M4V, AVI, WEBM
```

Recognized audio files:

```text
MP3, M4A, WAV, AAC, FLAC, OGG, OPUS, WMA
```

DRM-protected or damaged media files may fail.

## Basic Use

1. Place one or more supported files into the `Input` folder.
2. Run `transcribe.ps1` with PowerShell.
3. Press Enter to start.
4. Choose a file number, or choose `B` to process all files.
5. Choose an output mode.
6. Choose Fast or Accurate transcription mode.
7. Review the results in the `Output` folder.

## File Selection

When files are found, the script shows a menu like this:

```text
Recognized files found:
  [1] First file.mp4
  [2] Second file.mp3
  [B] Process all files
  [Q] Quit
```

Choose a number to process one file.

Choose `B` to process all recognized files in the `Input` folder.

Choose `Q` to quit.

## Output Modes

### Default Mode

Default mode creates:

```text
Original file
WAV audio file
TXT transcript
```

This is recommended for most users.

### Full Mode

Full mode creates:

```text
Original file
WAV audio file
TXT transcript
SRT subtitle file
VTT subtitle file
TSV timing file
JSON Whisper output
```

Use Full mode when caption/subtitle files or detailed Whisper output are needed.

## Transcription Modes

### Fast

Fast mode is the default. It is quicker and works well for most audio.

Pressing Enter at the mode prompt uses Fast mode.

### Accurate

Accurate mode is slower and uses a larger model. It may help when Fast mode misses words or the audio is harder to understand.

## Batch Processing

Batch mode processes all recognized files in the `Input` folder.

Each file is processed one at a time.

Each file gets its own output folder.

At the end, the script shows a batch summary.

Example:

```text
Batch complete.

  ✅ First file.mp4
  ✅ Second file.mp3

Output folder:
  Output
```

## Run Again / Refresh

After processing finishes, the script asks what to do next:

```text
[R] Run again / return to file list
[O] Open output folder
[Q] Quit
```

Pressing Enter quits.

If no files are found, the script shows:

```text
[R] Refresh / check again
[O] Open Input folder
[Q] Quit
```

Pressing Enter refreshes. This lets you drop more files into the `Input` folder without restarting the script.

## Configuration

The script reads settings from `config.json`.

Current example:

```json
{
  "AppName": "MediaScribe",
  "BaseFolder": "D:\\CodexTests\\TranscribeTool-Codex",
  "InputFolder": "D:\\CodexTests\\TranscribeTool-Codex\\Input",
  "OutputFolder": "D:\\CodexTests\\TranscribeTool-Codex\\Output",
  "LogsFolder": "D:\\CodexTests\\TranscribeTool-Codex\\Logs",
  "ModelsFolder": "D:\\CodexTests\\TranscribeTool-Codex\\Models",
  "DefaultModel": "medium",
  "DefaultLanguage": "en",
  "OutputMode": "default",
  "MoveInputFolderFilesAfterProcessing": true,
  "ExternalFileArchiveBehavior": "LeaveOriginalInPlace"
}
```

## Notes

- FFmpeg extracts audio only.
- Audio is converted to mono 16 kHz WAV for consistency.
- Files inside the `Input` folder are moved into their output job folder after processing.
- External files used through parameter mode are left in place.
- Generated output files are ignored by Git.
