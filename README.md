# MediaScribe

MediaScribe is a local Windows transcription tool that creates transcripts and optional caption files from audio/video files.

It uses:

* FFmpeg to extract audio
* OpenAI Whisper to create transcripts, translations, and optional caption/subtitle files
* PowerShell for the current setup workflow, command-line engine, and Windows GUI wrapper

MediaScribe includes both:

* A PowerShell WinForms GUI for normal users
* A terminal version for fallback, development, and troubleshooting

The most important design rule remains:

**Do not break the CLI.**

The terminal workflow remains available as a stable fallback while the GUI continues to improve.

## Basic Idea

MediaScribe uses a simple folder workflow:

    Put files into Input
    Run MediaScribe
    Get results in Output

The GUI also lets users browse to another source folder, such as a USB drive, Downloads folder, Desktop folder, or external drive.

## Intended Use

MediaScribe is useful for many audio/video transcription needs.

A strong intended use case is Genealogy / Family History Center work.

For example, a patron may digitize old family media such as:

* 8mm film
* Super 8 film
* VHS
* VHS-C
* Video8
* Hi8
* Audio cassette
* Reel-to-reel tape

After the recording has been converted into a digital audio or video file, MediaScribe can create a written transcript.

This can help preserve and search:

* Family interviews
* Home movie narration
* Oral histories
* Family stories
* Funeral talks
* Memorial recordings
* Family gatherings
* Personal memories
* Church talks
* Speeches
* Lessons
* Discussions
* Dictation
* Meetings
* Other spoken media

## Recommended User Flow

Normal users should not need to run long PowerShell commands manually.

The intended flow is:

    Download / USB / Desktop / extracted ZIP folder
      Install.bat
        runs setup.ps1
          creates or repairs installed MediaScribe folder
            Start-MediaScribe-GUI.bat
              runs MediaScribe-GUI.ps1
                calls transcribe.ps1

The GUI is recommended for most users.

The terminal version remains available with:

    MediaScribe.bat

or:

    Start-MediaScribe.bat

depending on the installed/package folder.

## Install MediaScribe

Open the folder where you downloaded, extracted, or copied MediaScribe.

This might be:

* USB drive
* Downloads folder
* Desktop folder
* Extracted ZIP folder
* Project folder

Double-click:

    Install.bat

The installer launcher starts PowerShell and runs:

    setup.ps1

The setup script will ask where to install MediaScribe.

The default install location is usually:

    Documents\MediaScribe

Setup creates the installed MediaScribe folder and copies the needed files there.

If setup completes successfully and all required dependencies are available, setup may offer launch options such as:

    [1] Start MediaScribe GUI
    [2] Start MediaScribe Terminal
    [3] Open Instructions
    [Q] Quit setup

Choose the GUI for normal use.

## Reinstalling or Repairing MediaScribe

You can run `Install.bat` again to reinstall or repair MediaScribe.

This is useful if core app files were damaged, deleted, or need to be updated.

During reinstall or repair, setup may replace the core app files, including:

* transcribe.ps1
* MediaScribe-GUI.ps1
* README.md
* How to Start transcription.txt
* MediaScribe.bat
* Start-MediaScribe-GUI.bat
* config.json

Setup recreates required folders if they are missing.

Setup does **not** clear or delete files inside these folders:

* Input
* Output
* Logs
* Models
* Tools

This means existing media files, transcripts, WAV files, caption files, and logs should remain in place.

To remove MediaScribe, delete the installed MediaScribe folder.

## Installed Folder

After setup, the installed MediaScribe folder should look similar to this:

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
      MediaScribe-GUI.ps1
      MediaScribe.bat
      README.md
      Start-MediaScribe-GUI.bat
      transcribe.ps1

The local FFmpeg files are present when bundled FFmpeg was included in the package and copied during setup.

## Start MediaScribe After Installation

After MediaScribe is installed, open the installed MediaScribe folder.

For normal GUI use, double-click:

    Start-MediaScribe-GUI.bat

For terminal fallback use, double-click:

    MediaScribe.bat

or:

    Start-MediaScribe.bat

`Install.bat` is for installing, reinstalling, or repairing MediaScribe.

The GUI or terminal launcher is for normal use after installation.

## Developer / Workspace Start

When testing directly from the project workspace, you can run:

    .\Start-MediaScribe-GUI.bat

or:

    .\Start-MediaScribe.bat

You can also run the GUI directly:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\MediaScribe-GUI.ps1

You can run the terminal backend directly:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\transcribe.ps1

Direct PowerShell commands are mainly for development and testing.

Normal users should use the installer launcher first, then use the GUI launcher from the installed folder.

## GUI Overview

The MediaScribe GUI includes:

* Files section
* Transcription Settings section
* Status section
* Start Transcription button
* Open Output Folder button
* Clear Status Window button
* Close MediaScribe button

The GUI uses a Source folder.

By default, the Source folder is the configured Input folder.

Users can also browse to another folder, such as:

* USB drive
* Downloads folder
* Desktop folder
* External drive
* Other media folder

The GUI lists recognized files in the selected Source folder.

## GUI Support Window

The GUI runs inside a PowerShell host.

A minimized PowerShell support window may appear on the taskbar.

The support window title may say:

    DO NOT CLOSE - MediaScribe Support Window

This is normal.

Do not close the support window while MediaScribe is running.

Close MediaScribe from the GUI when finished.

## Supported Input Formats

Recognized video files:

    MP4, MKV, MOV, M4V, AVI, WEBM

Recognized audio files:

    MP3, M4A, WAV, AAC, FLAC, OGG, OPUS, WMA

DRM-protected or damaged media files may fail.

## What MediaScribe Creates

### Default Output

Default mode creates:

* Original file
* WAV audio
* TXT transcript

This is recommended for most users.

The GUI label is:

    Default - TXT only

### Full Output

Full mode creates:

* Original file
* WAV audio
* TXT transcript
* SRT subtitle file
* VTT subtitle file
* TSV timing file
* JSON Whisper output

The GUI label is:

    Full - TXT, SRT, VTT, TSV, JSON

Use Full mode when subtitle/caption files or detailed Whisper output are needed.

### Caption Use

Use `SRT` or `VTT` files for video caption/subtitle workflows.

## Transcription Modes

### Fast - recommended

Fast mode is the default.

It is recommended for most users.

Behind the scenes, Fast uses the configured/default Whisper model.

The current default model is:

    medium

### Accurate - slower, for difficult audio

Accurate mode is slower and uses the large Whisper model.

It may help when Fast mode misses words or the audio is harder to understand.

## Language and Output Text

MediaScribe separates two related choices:

1. Input Audio
2. Output Text

### Input Audio

Input Audio means the language being spoken in the recording.

GUI options include:

* English
* Auto-detect
* Chinese
* French
* German
* Italian
* Japanese
* Korean
* Portuguese
* Spanish

English is the default.

Use Auto-detect if you are not sure what language is being spoken.

If you know the spoken language, choosing it directly may give more consistent results.

Examples:

    English audio -> choose English
    Korean audio -> choose Korean
    Unknown language -> choose Auto-detect

### Output Text

Output Text controls what kind of text MediaScribe creates.

GUI options are:

* Same as input / detected
* English translation

### Same as input / detected

This creates a transcript in the same language as the audio.

Examples:

    English audio -> English transcript
    Korean audio -> Korean transcript
    Auto-detect Korean audio -> Korean transcript

This uses Whisper's normal transcription mode:

    --task transcribe

### English translation

This asks Whisper to translate the spoken audio into English.

Examples:

    Korean audio -> English text
    Spanish audio -> English text
    Auto-detect Korean audio -> English text

This uses Whisper's translation mode:

    --task translate

Important:

Whisper's built-in translation mode translates to English.

MediaScribe does not currently translate into every possible output language.

## Live Preview Behavior

For English transcription, MediaScribe can show live transcript preview lines while Whisper is working.

Live preview is enabled for:

    Input Audio: English
    Output Text: Same as input / detected

Live preview is hidden for:

* Auto-detect
* Non-English input languages
* English translation

This is intentional.

Some languages use characters that may not display correctly in the Windows status window.

When live preview is hidden, MediaScribe still creates the final transcript file.

For hidden-preview jobs, MediaScribe may save Whisper log files in the job folder:

    whisper_stdout.log
    whisper_stderr.log

These log files are normal.

They keep Whisper's progress/debug output out of the GUI status window.

## Project Folders

### Input

Put supported audio or video files here before running MediaScribe, unless using the GUI to browse to another Source folder.

### Output

Transcription results are saved here.

Each processed file gets its own output folder.

Example:

    Output/
      My Recording/
        My Recording.mp4
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

## Basic GUI Use After Installation

1. Open the installed MediaScribe folder.
2. Double-click `Start-MediaScribe-GUI.bat`.
3. Put media files in the Input folder, or browse to another Source folder.
4. Choose a file from the Selected file dropdown.
5. Choose Output mode.
6. Choose Transcription mode.
7. Choose Input Audio.
8. Choose Output Text.
9. Click Start Transcription.
10. Review the results in the Output folder.

## Basic Terminal Use After Installation

1. Open the installed MediaScribe folder.
2. Put one or more supported files into the `Input` folder.
3. Double-click `MediaScribe.bat`.
4. Press Enter to start.
5. Choose a file number, or choose `B` to process all files.
6. Choose an output mode.
7. Choose Fast or Accurate transcription mode.
8. Wait while FFmpeg extracts audio and Whisper transcribes.
9. Review the results in the `Output` folder.

The terminal version remains useful for fallback and troubleshooting.

## Terminal Interface

MediaScribe uses a colored terminal interface with consistent section banners and status labels.

Common labels include:

* `[INFO]`
* `[OK]`
* `[WARN]`
* `[ERROR]`

The setup and transcription tools use a similar style so the install-to-first-run flow feels like one app.

## File Selection in Terminal

When files are found, MediaScribe shows a menu like this:

    Recognized files found:
      [1] First file.mp4
      [2] Second file.mp3
      [B] Process all files
      [Q] Quit

Choose a number to process one file.

Choose `B` to process all recognized files in the `Input` folder.

Choose `Q` to quit.

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

Pressing Enter refreshes.

This lets you drop more files into the `Input` folder without restarting MediaScribe.

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

## Dependencies

MediaScribe needs:

* Python
* pip
* OpenAI Whisper
* FFmpeg

The setup script checks for these dependencies.

MediaScribe files may still install if dependencies are missing, but transcription will not work until the missing dependencies are installed or fixed.

After fixing missing dependencies, run `Install.bat` again to re-check setup.

## Bundled Dependencies

MediaScribe may include dependency installers or tools in the package folder.

### FFmpeg

Bundled FFmpeg should be placed in:

    Dependencies\FFmpeg\

Expected files:

* ffmpeg.exe
* ffprobe.exe

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

    python -m ensurepip --upgrade

### OpenAI Whisper

OpenAI Whisper is installed using pip if it is missing.

Installing Whisper requires internet access.

If internet access is unavailable or Whisper installation fails, setup should not crash.

It may finish with missing dependencies.

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

MediaScribe currently prefers `python -m whisper` because it avoids some Windows Application Control issues with the generated `whisper.exe` launcher.

## Configuration

MediaScribe reads settings from `config.json`.

Example installed config:

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

The default input audio language.

Current default:

    en

### OutputMode

The default output mode.

Supported values:

* `default`
* `full`

### MoveInputFolderFilesAfterProcessing

When true, files placed inside the Input folder are moved into their output/job folder after successful processing.

The original file is moved only after expected transcript outputs are created.

### ExternalFileArchiveBehavior

Controls behavior for files processed from outside the Input folder.

Currently supported behavior:

* `LeaveOriginalInPlace`
* `CopyToJobFolder`

The default behavior is:

    LeaveOriginalInPlace

## File Handling Notes

* FFmpeg extracts audio only.
* Audio is converted to mono 16 kHz WAV for consistency.
* Files inside the `Input` folder are moved into their output job folder after successful processing.
* External files used through parameter mode are left in place by default.
* The original media file is moved only after the expected transcript output is created.
* Generated output files are ignored by Git.
* `Install.bat` is for installation, reinstall, or repair.
* The GUI launcher is recommended for daily use after installation.
* `MediaScribe.bat` remains available for terminal/fallback use.
* `Start-MediaScribe.bat` is useful for workspace/developer testing.
* To uninstall MediaScribe, delete the installed MediaScribe folder.

## Current GUI Status

The current GUI includes:

* Source folder selection
* File dropdown
* Browse Folder
* Refresh Files
* Open Source Folder
* Output Mode dropdown
* Transcription Mode dropdown
* Input Audio dropdown
* Output Text dropdown
* Start Transcription button
* Open Output Folder button
* Clear Status Window button
* Close MediaScribe button
* Status/progress window
* Minimized support window

The GUI calls the existing `transcribe.ps1` backend.

The CLI should remain available as a supported fallback.