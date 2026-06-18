# MediaScribe

MediaScribe is a local Windows transcription tool that creates transcripts and caption files from audio/video files.

It uses:

* FFmpeg to extract audio
* OpenAI Whisper to create transcripts and optional caption/subtitle files
* PowerShell for the current command-line engine and setup workflow

MediaScribe is currently PowerShell-based. A GUI is planned for a future version.

## Basic Idea

MediaScribe uses a simple folder workflow:

Put files into Input
Run MediaScribe
Get results in Output


## Recommended User Flow

Normal users should not need to run long PowerShell commands manually.

The intended flow is:

Download / USB / Desktop / extracted ZIP folder
  Install.bat or Install-MediaScribe.bat
    runs setup.ps1
      creates or repairs installed MediaScribe folder
        MediaScribe.bat
          runs transcribe.ps1


After a successful install, setup can also offer to run MediaScribe immediately.

For daily use after installation, run:

MediaScribe.bat


from the installed MediaScribe folder.

## Install MediaScribe

Open the folder where you downloaded, extracted, or copied MediaScribe.

This might be:

USB drive
Downloads folder
Desktop folder
Extracted ZIP folder
Project folder


Double-click:
Install.bat


or:

Install-MediaScribe.bat


The installer launcher starts PowerShell and runs:

powershell
setup.ps1


The setup script will ask where to install MediaScribe.

The default install location is usually:

Documents\MediaScribe


Setup creates the installed MediaScribe folder and copies the needed files there.

If setup completes successfully and all required dependencies are available, setup can ask:

Run MediaScribe now? (Y/N, default Y)


Press Enter or choose `Y` to start MediaScribe immediately.

Choose `N` if you want to run MediaScribe later.

## Reinstalling or Repairing MediaScribe

You can run `Install.bat` again to reinstall or repair MediaScribe.

This is useful if core app files were damaged, deleted, or need to be updated.

During reinstall or repair, setup may replace the core app files, including:

transcribe.ps1
README.md
How to Start transcription.txt
MediaScribe.bat
config.json


Setup recreates required folders if they are missing.

Setup does **not** clear or delete files inside these folders:

Input
Output
Logs
Models
Tools


This means existing media files, transcripts, WAV files, caption files, and logs should remain in place.

To remove MediaScribe, delete the installed MediaScribe folder.

## Installed Folder

After setup, the installed MediaScribe folder should look like this:

MediaScribe/
  Input/
  Output/
  Logs/
  Models/
  Tools/
    ffmpeg/
      ffmpeg.exe
      ffprobe.exe
  config.json
  How to Start transcription.txt
  MediaScribe.bat
  README.md
  transcribe.ps1


The local FFmpeg files are present when bundled FFmpeg was included in the package and copied during setup.

## Start MediaScribe After Installation

After MediaScribe is installed, open the installed MediaScribe folder.

Then double-click:
MediaScribe.bat


You can also run it from PowerShell:

powershell
.\MediaScribe.bat


`MediaScribe.bat` starts the installed copy of `transcribe.ps1`.

`Install.bat` is for installing, reinstalling, or repairing MediaScribe.

`MediaScribe.bat` is for normal daily use after installation.

## Developer / Workspace Start

When testing directly from the project workspace, you can run:

powershell
.\Start-MediaScribe.bat


or run the PowerShell script directly:

powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\transcribe.ps1


This direct command is mainly for development and testing.

Normal users should use the installer launcher first, then use `MediaScribe.bat` from the installed folder.

## What MediaScribe Creates

### Default Output

Default mode creates:

Original file
WAV audio
TXT transcript


This is recommended for most users.

### Full Output

Full mode creates:

Original file
WAV audio
TXT transcript
SRT subtitle file
VTT subtitle file
TSV timing file
JSON Whisper output


Use Full mode when subtitle/caption files or detailed Whisper output are needed.

### Caption Use

Use `SRT` or `VTT` files for video caption/subtitle workflows.

## Project Folders

### Input

Put supported audio or video files here before running MediaScribe.

### Output

Transcription results are saved here.

Each processed file gets its own output folder.

Example:

Output/
  My Recording/
    My Recording.mp3
    My Recording.wav
    My Recording.txt


If an output folder already exists for a file name, MediaScribe creates a timestamped sibling folder.

### Logs

Reserved for logging support.

### Models

Reserved for model-related support.

### Tools

Reserved for bundled tools.

Bundled FFmpeg is copied into:
Tools\ffmpeg\


The local FFmpeg executable path is:
Tools\ffmpeg\ffmpeg.exe


MediaScribe prefers local bundled FFmpeg if present, then falls back to system FFmpeg from PATH.

## Supported Input Formats

Recognized video files:
MP4, MKV, MOV, M4V, AVI, WEBM


Recognized audio files:
MP3, M4A, WAV, AAC, FLAC, OGG, OPUS, WMA


DRM-protected or damaged media files may fail.

## Basic Use After Installation

1. Open the installed MediaScribe folder.
2. Put one or more supported files into the `Input` folder.
3. Double-click `MediaScribe.bat`.
4. Press Enter to start.
5. Choose a file number, or choose `B` to process all files.
6. Choose an output mode.
7. Choose Fast or Accurate transcription mode.
8. Wait while FFmpeg extracts audio and Whisper transcribes.
9. Review the results in the `Output` folder.

## Terminal Interface

MediaScribe uses a colored terminal interface with consistent section banners and status labels.

Common labels include:

[INFO]
[OK]
[WARN]
[ERROR]


The setup and transcription tools use a similar style so the install-to-first-run flow feels like one app.

## File Selection

When files are found, MediaScribe shows a menu like this:

Recognized files found:
  [1] First file.mp4
  [2] Second file.mp3
  [B] Process all files
  [Q] Quit


Choose a number to process one file.

Choose `B` to process all recognized files in the `Input` folder.

Choose `Q` to quit.

## Output Modes

### Default Mode

Default mode creates:

Original file
WAV audio file
TXT transcript


This is recommended for most users.

### Full Mode

Full mode creates:

Original file
WAV audio file
TXT transcript
SRT subtitle file
VTT subtitle file
TSV timing file
JSON Whisper output


Use Full mode when caption/subtitle files or detailed Whisper output are needed.

## Transcription Modes

### Fast

Fast mode is the default. It is quicker and works well for most audio.

Pressing Enter at the mode prompt uses Fast mode.

Fast mode uses the configured/default Whisper model.

The current default model is:
medium


### Accurate

Accurate mode is slower and uses the large Whisper model.

It may help when Fast mode misses words or the audio is harder to understand.

## While Transcribing

MediaScribe first extracts audio with FFmpeg.

FFmpeg output is minimized so normal users do not have to see technical FFmpeg chatter.

Then MediaScribe runs Whisper.

During Whisper transcription, live transcript progress appears in the terminal.

This progress may appear in chunks and may take a while, especially for longer files or larger Whisper models.

This is normal and helps show that transcription is still working.

## Batch Processing

Batch mode processes all recognized files in the `Input` folder.

Each file is processed one at a time.

Each file gets its own output folder.

At the end, MediaScribe shows a batch summary.

Example:

Batch Summary

[OK] First file.mp4
[OK] Second file.mp3

Output folder:
  Output


## Run Again / Refresh

After processing finishes, MediaScribe asks what to do next:

[R] Run again / return to file list
[O] Open output folder
[Q] Quit


Pressing Enter quits.

If no files are found, MediaScribe shows:

[R] Refresh / check again
[O] Open Input folder
[Q] Quit


Pressing Enter refreshes. This lets you drop more files into the `Input` folder without restarting MediaScribe.

## Dependencies

MediaScribe needs:

Python
pip
OpenAI Whisper
FFmpeg


The setup script checks for these dependencies.

MediaScribe files may still install if dependencies are missing, but transcription will not work until the missing dependencies are installed or fixed.

After fixing missing dependencies, run `Install.bat` again to re-check setup.

## Bundled Dependencies

MediaScribe may include dependency installers or tools in the package folder.

### FFmpeg

Bundled FFmpeg should be placed in:
Dependencies\FFmpeg\


Expected files:

ffmpeg.exe
ffprobe.exe


During setup, bundled FFmpeg is copied into the installed runtime folder:
Tools\ffmpeg\


MediaScribe then uses:
Tools\ffmpeg\ffmpeg.exe


### Python

A bundled Python installer may be placed in:
Dependencies\Python\


Example:
python-3.13.7-amd64.exe


If Python is missing, setup can offer to run the bundled Python installer.

### pip

pip is handled through Python.

If Python is available but pip is missing, setup can try:

powershell
python -m ensurepip --upgrade


### OpenAI Whisper

OpenAI Whisper is installed using pip if it is missing.

Installing Whisper requires internet access.

If internet access is unavailable or Whisper installation fails, setup should not crash. It may finish with missing dependencies.

After fixing internet access or dependencies, run `Install.bat` again.

## FFmpeg Lookup

MediaScribe looks for FFmpeg in this order:

1. Local `Tools\ffmpeg\ffmpeg.exe`
2. System `ffmpeg` from PATH

If bundled FFmpeg is missing but system FFmpeg is found, MediaScribe can still work.

If both bundled FFmpeg and system FFmpeg are missing, MediaScribe cannot transcribe.

## Whisper Lookup

MediaScribe looks for Whisper in this order:

1. `python -m whisper`
2. Global `whisper.exe` / `whisper` command

This lets MediaScribe work with either the Python module path or an existing global Whisper command.

## Configuration

MediaScribe reads settings from `config.json`.

Example installed config:

json
{
  "AppName": "MediaScribe",
  "BaseFolder": "D:\\Documents\\MediaScribe",
  "InputFolder": "D:\\Documents\\MediaScribe\\Input",
  "OutputFolder": "D:\\Documents\\MediaScribe\\Output",
  "LogsFolder": "D:\\Documents\\MediaScribe\\Logs",
  "ModelsFolder": "D:\\Documents\\MediaScribe\\Models",
  "DefaultModel": "medium",
  "DefaultLanguage": "en",
  "OutputMode": "default",
  "MoveInputFolderFilesAfterProcessing": true,
  "ExternalFileArchiveBehavior": "LeaveOriginalInPlace"
}


## Configuration Fields

### AppName

The app name shown in the startup banner.

### BaseFolder

The main installed MediaScribe folder.

### InputFolder

Where users place audio/video files before transcription.

### OutputFolder

Where MediaScribe saves transcripts, WAV files, captions, and archived originals.

### LogsFolder

Reserved for logs.

### ModelsFolder

Reserved for model-related support.

### DefaultModel

The default Whisper model.

Current default:

medium


### DefaultLanguage

The default transcription language.

Current default:

en


### OutputMode

The default output mode.

Supported values:

default
full


### MoveInputFolderFilesAfterProcessing

When true, files placed inside the Input folder are moved into their output/job folder after successful processing.

### ExternalFileArchiveBehavior

Controls behavior for files processed from outside the Input folder.

Currently supported behavior:


LeaveOriginalInPlace
CopyToJobFolder


The default behavior is:


LeaveOriginalInPlace


## Notes

* FFmpeg extracts audio only.
* Audio is converted to mono 16 kHz WAV for consistency.
* Files inside the `Input` folder are moved into their output job folder after successful processing.
* External files used through parameter mode are left in place by default.
* Generated output files are ignored by Git.
* `Install.bat` or `Install-MediaScribe.bat` is for installation, reinstall, or repair.
* `MediaScribe.bat` is for daily use after installation.
* `Start-MediaScribe.bat` is for workspace/developer testing.
* To uninstall MediaScribe, delete the installed MediaScribe folder.

## Planned GUI

A GUI is planned for a future version.

The recommended GUI direction is to wrap the existing working PowerShell workflow first, rather than rewriting the transcription engine immediately.

Possible GUI phases:

1. Simple launcher/wrapper
2. Better installed app experience
3. Shared engine cleanup
4. GUI polish

The current PowerShell CLI should remain stable while GUI work begins.
