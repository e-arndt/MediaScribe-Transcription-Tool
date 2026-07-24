MediaScribe

MediaScribe is a local Windows transcription tool that creates transcripts and optional caption files from audio and video files.

It uses:

FFmpeg to extract audio

OpenAI Whisper to create transcripts, English translations, and optional caption/subtitle files

PowerShell for the setup workflow, command-line engine, and Windows GUI wrapper

MediaScribe includes both:

A PowerShell WinForms GUI for normal users

A terminal version for fallback, development, and troubleshooting

The most important design rule remains:

Do not break the CLI.

The terminal workflow remains available as a stable fallback while the GUI continues to improve.

Current Feature Summary

The current version includes:

Single-file transcription through the GUI

Sequential multiple-file transcription through the GUI

Terminal single-file and Input-folder batch processing

Default and Full output modes

Fast and Accurate transcription modes

English, Auto-detect, and selected non-English source languages

Same-language transcription or English translation

English live-preview behavior

Hidden preview with UTF-8 log handling for Auto-detect, non-English, and translation jobs

Separate output/job folder for every processed file

Safe movement of Input-folder originals only after successful output verification

Automatic GUI source-list refresh after processing

Safe GUI Stop Transcription control

Full active child-process-tree termination for FFmpeg, Python, and Whisper

Single-file Stop and full-batch abort behavior

ABORTED_ marking for incomplete output folders

Distinct stopped-operation exit code 2

UTF-8-safe filename and status output

A preserved terminal/CLI fallback

Basic Idea

MediaScribe uses a simple folder workflow:

Put files into InputRun MediaScribeGet results in Output

The GUI also lets users browse to another Source folder, such as a USB drive, Downloads folder, Desktop folder, or external drive.

The user can process either:

One selected file

or:

All recognized files in the current Source folder

Multiple-file mode captures the recognized file list and sends the files to the existing transcription engine one at a time.

Intended Use

MediaScribe is useful for many audio/video transcription needs.

A strong intended use case is Genealogy / Family History Center work.

For example, a patron may digitize old family media such as:

8mm film

Super 8 film

VHS

VHS-C

Video8

Hi8

Audio cassette

Reel-to-reel tape

After the recording has been converted into a digital audio or video file, MediaScribe can create a written transcript.

This can help preserve and search:

Family interviews

Home movie narration

Oral histories

Family stories

Funeral talks

Memorial recordings

Family gatherings

Personal memories

Church talks

Speeches

Lessons

Discussions

Dictation

Meetings

Other spoken media

Recommended User Flow

Normal users should not need to run long PowerShell commands manually.

The intended flow is:

Download / USB / Desktop / extracted ZIP folderInstall.batruns setup.ps1creates or repairs installed MediaScribe folderStart-MediaScribe-GUI.batruns MediaScribe-GUI.ps1calls transcribe.ps1

The GUI is recommended for most users.

The terminal version remains available with:

MediaScribe.bat

or:

Start-MediaScribe.bat

depending on the installed/package folder.

Install MediaScribe

Open the folder where you downloaded, extracted, or copied MediaScribe.

This might be:

USB drive

Downloads folder

Desktop folder

Extracted ZIP folder

Project folder

Double-click:

Install.bat

The installer launcher starts PowerShell and runs:

setup.ps1

The setup script will ask where to install MediaScribe.

The default install location is usually:

Documents\MediaScribe

Setup creates the installed MediaScribe folder and copies the needed files there.

If setup completes successfully and all required dependencies are available, setup may offer launch options such as:

[1] Start MediaScribe GUI[2] Start MediaScribe Terminal[3] Open Instructions[Q] Quit setup

Choose the GUI for normal use.

Reinstalling or Repairing MediaScribe

You can run Install.bat again to reinstall or repair MediaScribe.

This is useful if core app files were damaged, deleted, or need to be updated.

During reinstall or repair, setup may replace the core app files, including:

transcribe.ps1

MediaScribe-GUI.ps1

README.md

Quick Start and Instructions.txt

MediaScribe.bat

Start-MediaScribe-GUI.bat

config.json

Setup recreates required folders if they are missing.

Setup does not clear or delete files inside these folders:

Input

Output

Logs

Models

Tools

This means existing media files, transcripts, WAV files, caption files, and logs should remain in place.

To remove MediaScribe, delete the installed MediaScribe folder.

Installed Folder

After setup, the installed MediaScribe folder should look similar to this:

MediaScribe/Input/Output/Logs/Models/Tools/ffmpeg/ffmpeg.exeffprobe.execonfig.jsonQuick Start and Instructions.txtMediaScribe-GUI.ps1MediaScribe.batREADME.mdStart-MediaScribe-GUI.battranscribe.ps1

The local FFmpeg files are present when bundled FFmpeg was included in the package and copied during setup.

Start MediaScribe After Installation

After MediaScribe is installed, open the installed MediaScribe folder.

For normal GUI use, double-click:

Start-MediaScribe-GUI.bat

For terminal fallback use, double-click:

MediaScribe.bat

or:

Start-MediaScribe.bat

Install.bat is for installing, reinstalling, or repairing MediaScribe.

The GUI or terminal launcher is for normal use after installation.

Developer / Workspace Start

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

GUI Overview

The MediaScribe GUI includes:

Files section

Source folder field

Selected file dropdown

Selected file / All files in source folder controls

Browse Folder button

Refresh Files button

Open Source Folder button

Transcription Settings section

Output Mode dropdown

Transcription Mode dropdown

Input Audio dropdown

Output Text dropdown

Status section

Start Transcription / Start Batch Transcription button

Stop Transcription button

Open Output Folder button

Clear Status Window button

Close MediaScribe button

The GUI uses a Source folder.

By default, the Source folder is the configured Input folder.

Users can also browse to another folder, such as:

USB drive

Downloads folder

Desktop folder

External drive

Other media folder

The GUI lists recognized files in the selected Source folder.

After a single job or batch finishes, the GUI refreshes the Source-folder file list.

GUI Support Window

The GUI runs inside a PowerShell host.

A minimized PowerShell support window may appear on the taskbar.

The support window title may say:

DO NOT CLOSE - MediaScribe Support Window

This is normal.

Do not close the support window while MediaScribe is running.

Close MediaScribe from the GUI when finished.

Closing the GUI remains blocked while transcription is active. Use Stop Transcription to cancel the active operation safely, then close MediaScribe after it returns to an idle state.

Supported Input Formats

Recognized video files:

MP4, MKV, MOV, M4V, AVI, WEBM

Recognized audio files:

MP3, M4A, WAV, AAC, FLAC, OGG, OPUS, WMA

DRM-protected or damaged media files may fail.

What MediaScribe Creates

Default Output

Default mode creates:

Original file

WAV audio

TXT transcript

This is recommended for most users.

The GUI wording is:

Default - Original file, WAV audio, TXT transcript

Full Output

Full mode creates:

Original file

WAV audio

TXT transcript

SRT subtitle file

VTT subtitle file

TSV timing file

JSON Whisper output

The GUI wording is:

Full - Original file, WAV audio, TXT, SRT, VTT, TSV, JSON

Use Full mode when subtitle/caption files or detailed Whisper output are needed.

Caption Use

Use SRT or VTT files for video caption/subtitle workflows.

Transcription Modes

Fast - recommended

Fast mode is the default.

It is recommended for most users.

Behind the scenes, Fast uses the configured/default Whisper model.

The current default model is:

medium

Accurate - slower, for difficult audio

Accurate mode is slower and uses the large Whisper model.

It may help when Fast mode misses words or the audio is harder to understand.

Language and Output Text

MediaScribe separates two related choices:

Input Audio

Output Text

Input Audio

Input Audio means the language being spoken in the recording.

GUI options include:

English

Auto-detect

Chinese

French

German

Italian

Japanese

Korean

Portuguese

Spanish

English is the default.

Use Auto-detect if you are not sure what language is being spoken.

If you know the spoken language, choosing it directly may give more consistent results.

Examples:

English audio -> choose EnglishKorean audio -> choose KoreanUnknown language -> choose Auto-detect

Input Audio in Multiple-File Mode

The selected Input Audio setting applies to every file in the batch.

For a mixed-language folder, select:

Auto-detect

Auto-detect evaluates each file independently.

A tested mixed-language batch correctly handled English and Korean files in one run. With Output Text set to Same as input / detected, the Korean audio produced Korean text while the English files produced English text.

Choosing a specific language forces that language for every file in the batch.

For example, selecting English tells Whisper to treat every file as English. Non-English recordings may then produce inaccurate, incomplete, or unusable text.

Output Text

Output Text controls what kind of text MediaScribe creates.

GUI options are:

Same as input / detected

English translation

Same as input / detected

This creates a transcript in the same language as the audio.

Examples:

English audio -> English transcriptKorean audio -> Korean transcriptAuto-detect Korean audio -> Korean transcript

This uses Whisper's normal transcription mode:

--task transcribe

English translation

This asks Whisper to translate the spoken audio into English.

Examples:

Korean audio -> English textSpanish audio -> English textAuto-detect Korean audio -> English text

This uses Whisper's translation mode:

--task translate

Important:

Whisper's built-in translation mode translates to English.

MediaScribe does not currently translate into every possible output language.

Recommended Mixed-Language Batch Settings

To preserve each recording's language:

Input Audio: Auto-detectOutput Text: Same as input / detected

To convert all supported spoken languages to English text:

Input Audio: Auto-detectOutput Text: English translation

Live Preview Behavior

For English transcription, MediaScribe can show live transcript preview lines while Whisper is working.

Live preview is enabled for:

Input Audio: EnglishOutput Text: Same as input / detected

Live preview is hidden for:

Auto-detect

Non-English input languages

English translation

This is intentional.

Some languages use characters that may not display correctly in the Windows status window.

When live preview is hidden, MediaScribe still creates the final transcript file.

For hidden-preview jobs, MediaScribe may save Whisper log files in the job folder:

whisper_stdout.logwhisper_stderr.log

These log files are normal.

They keep Whisper's progress/debug output out of the GUI status window.

Project Folders

Input

Put supported audio or video files here before running MediaScribe, unless using the GUI to browse to another Source folder.

Output

Transcription results are saved here.

Each processed file gets its own output folder.

Example:

Output/My Recording/My Recording.mp4My Recording.wavMy Recording.txt

If an output folder already exists for a file name, MediaScribe creates a timestamped sibling folder.

Logs

Reserved for logging support.

Models

Reserved for model-related support.

Tools

Reserved for bundled tools.

Bundled FFmpeg is copied into:

Tools\ffmpeg

The local FFmpeg executable path is:

Tools\ffmpeg\ffmpeg.exe

MediaScribe prefers local bundled FFmpeg if present, then falls back to system FFmpeg from PATH.

Basic GUI Use After Installation

Process One File

Open the installed MediaScribe folder.

Double-click Start-MediaScribe-GUI.bat.

Put media files in the Input folder, or browse to another Source folder.

Choose Selected file.

Choose a file from the Selected file dropdown.

Choose Output mode.

Choose Transcription mode.

Choose Input Audio.

Choose Output Text.

Click Start Transcription.

Review the results in the Output folder.

Process All Files in the Source Folder

Open the installed MediaScribe folder.

Double-click Start-MediaScribe-GUI.bat.

Put the desired files in the Input folder, or browse to another Source folder.

Choose All files in source folder.

Choose Output mode.

Choose Transcription mode.

Choose Input Audio.

Choose Output Text.

Click Start Transcription.

Review the final batch summary.

Review the separate output folder created for each file.

For folders containing more than one spoken language, use Auto-detect.

To cancel a running GUI operation safely, click Stop Transcription and confirm the request. The default confirmation choice keeps the transcription running.

GUI Multiple-File Mode

GUI Multiple-File Mode processes all recognized media files in the current Source folder.

The implementation intentionally reuses the existing single-file transcription engine.

The GUI/backend orchestration:

Captures the recognized file list before processing begins.

Sends the first file to the normal transcription engine.

Waits for that file to finish.

Records its success or failure.

Sends the next file to the same engine.

Continues until the captured list is finished.

Displays a final batch summary.

Refreshes the Source-folder file list.

The files are processed sequentially, never in parallel.

The same settings are used for every file:

Output mode

Transcription mode/model

Input Audio

Output Text/task

Each file receives its own job folder and its own file-safety decision.

The batch wrapper does not replace the transcription engine or combine several recordings into one output folder.

Multiple-File File Handling

For every file in the batch:

A separate output/job folder is created.

The normal FFmpeg and Whisper workflow runs.

Expected transcript output is verified.

An Input-folder original is moved only after that individual file succeeds.

A failed Input-folder original remains in place.

An external source original remains in place by default.

A timestamped sibling output folder is used if the normal name already exists.

Processing continues to later files after an individual failure.

After the batch finishes, the GUI refreshes the current Source folder.

A successfully processed Input-folder file disappears from the dropdown/list because it was moved into its job folder.

An external file remains listed because its source original remains in the external folder.

Batch Summary

At the end of multiple-file processing, MediaScribe displays a batch summary.

The exact presentation may vary, but it identifies the files found and whether each file completed or failed.

Conceptual example:

Batch transcription complete.Files found: 6Completed: 5Failed: 1

Each successfully completed file remains available in its own Output folder even when another file in the batch fails.

When a batch is stopped, the summary reports:

Batch stopped by user.Files foundCompletedFailedStoppedNot started

Basic Terminal Use After Installation

Open the installed MediaScribe folder.

Put one or more supported files into the Input folder.

Double-click MediaScribe.bat.

Press Enter to start.

Choose a file number, or choose B to process all files.

Choose an output mode.

Choose Fast or Accurate transcription mode.

Wait while FFmpeg extracts audio and Whisper transcribes.

Review the results in the Output folder.

The terminal version remains useful for fallback and troubleshooting.

Terminal Interface

MediaScribe uses a colored terminal interface with consistent section banners and status labels.

Common labels include:

[INFO]

[OK]

[WARN]

[ERROR]

The setup and transcription tools use a similar style so the install-to-first-run flow feels like one app.

File Selection in Terminal

When files are found, MediaScribe shows a menu like this:

Recognized files found:[1] First file.mp4[2] Second file.mp3[B] Process all files[Q] Quit

Choose a number to process one file.

Choose B to process all recognized files in the Input folder.

Choose Q to quit.

Run Again / Refresh

After processing finishes, MediaScribe asks what to do next:

[R] Run again / return to file list[O] Open output folder[Q] Quit

Pressing Enter quits.

If no files are found, MediaScribe shows:

[R] Refresh / check again[O] Open Input folder[Q] Quit

Pressing Enter refreshes.

This lets you drop more files into the Input folder without restarting MediaScribe.

Terminal Batch Processing

Terminal batch mode processes all recognized files in the Input folder.

Each file is processed one at a time.

Each file gets its own output folder.

At the end, MediaScribe shows a batch summary.

Example:

Batch Summary

[OK] First file.mp4[OK] Second file.mp3

Output folder:Output

Dependencies

MediaScribe needs:

Python

pip

OpenAI Whisper

FFmpeg

The setup script checks for these dependencies.

MediaScribe files may still install if dependencies are missing, but transcription will not work until the missing dependencies are installed or fixed.

After fixing missing dependencies, run Install.bat again to re-check setup.

Bundled Dependencies

MediaScribe may include dependency installers or tools in the package folder.

FFmpeg

Bundled FFmpeg should be placed in:

Dependencies\FFmpeg

Expected files:

ffmpeg.exe

ffprobe.exe

During setup, bundled FFmpeg is copied into the installed runtime folder:

Tools\ffmpeg

MediaScribe then uses:

Tools\ffmpeg\ffmpeg.exe

Python

A bundled Python installer may be placed in:

Dependencies\Python

Example:

python-3.13.7-amd64.exe

If Python is missing, setup can offer to run the bundled Python installer.

pip

pip is handled through Python.

If Python is available but pip is missing, setup can try:

python -m ensurepip --upgrade

OpenAI Whisper

OpenAI Whisper is installed using pip if it is missing.

Installing Whisper requires internet access.

If internet access is unavailable or Whisper installation fails, setup should not crash.

It may finish with missing dependencies.

After fixing internet access or dependencies, run Install.bat again.

FFmpeg Lookup

MediaScribe looks for FFmpeg in this order:

Local Tools\ffmpeg\ffmpeg.exe

System ffmpeg from PATH

If bundled FFmpeg is missing but system FFmpeg is found, MediaScribe can still work.

If both bundled FFmpeg and system FFmpeg are missing, MediaScribe cannot transcribe.

Whisper Lookup

MediaScribe looks for Whisper in this order:

python -m whisper

Global whisper.exe / whisper command

MediaScribe currently prefers python -m whisper because it avoids some Windows Application Control issues with the generated whisper.exe launcher.

Configuration

MediaScribe reads settings from config.json.

Example installed config:

{"AppName": "MediaScribe","BaseFolder": "D:\Documents\MediaScribe","InputFolder": "D:\Documents\MediaScribe\Input","OutputFolder": "D:\Documents\MediaScribe\Output","LogsFolder": "D:\Documents\MediaScribe\Logs","ModelsFolder": "D:\Documents\MediaScribe\Models","DefaultModel": "medium","DefaultLanguage": "en","OutputMode": "default","MoveInputFolderFilesAfterProcessing": true,"ExternalFileArchiveBehavior": "LeaveOriginalInPlace"}

Configuration Fields

AppName

The app name shown in the startup banner.

BaseFolder

The main installed MediaScribe folder.

InputFolder

Where users place audio/video files before transcription.

OutputFolder

Where MediaScribe saves transcripts, WAV files, captions, and archived originals.

LogsFolder

Reserved for logs.

ModelsFolder

Reserved for model-related support.

DefaultModel

The default Whisper model.

Current default:

medium

DefaultLanguage

The default input audio language.

Current default:

en

OutputMode

The default output mode.

Supported values:

default

full

MoveInputFolderFilesAfterProcessing

When true, files placed inside the Input folder are moved into their output/job folder after successful processing.

The original file is moved only after expected transcript outputs are created.

ExternalFileArchiveBehavior

Controls behavior for files processed from outside the Input folder.

Currently supported behavior:

LeaveOriginalInPlace

CopyToJobFolder

The default behavior is:

LeaveOriginalInPlace

Parameter-Mode Backend

The GUI calls transcribe.ps1 in non-interactive parameter mode.

The single-file interface includes:

-InputFile <path>-OutputMode default|full-Model medium|large-Language en|auto|<Whisper language code>-Task transcribe|translate-StopRequestFile <temporary stop-request path>-StateFile <temporary JSON state path>

The StopRequestFile and StateFile parameters support cooperative GUI cancellation, active-stage tracking, orderly cleanup, and forced process-tree fallback if normal stopping hangs.

The multiple-file GUI route uses the backend's non-interactive folder/batch support while preserving the existing interactive terminal batch mode and single-file parameter mode.

The GUI should continue calling the existing backend rather than duplicating the transcription engine inside the WinForms script.

File Handling Notes

FFmpeg extracts audio only.

Audio is converted to mono 16 kHz WAV for consistency.

Files inside the Input folder are moved into their output job folder after successful processing.

External files are left in place by default.

The original media file is moved only after the expected transcript output is created.

Multiple-file mode applies these rules separately to each file.

Generated output files are ignored by Git.

Install.bat is for installation, reinstall, or repair.

The GUI launcher is recommended for daily use after installation.

MediaScribe.bat remains available for terminal/fallback use.

Start-MediaScribe.bat is useful for workspace/developer testing.

To uninstall MediaScribe, delete the installed MediaScribe folder.

Current GUI Status

The current GUI includes:

Source folder selection

Selected-file dropdown

Selected file / All files in source folder choice

Browse Folder

Refresh Files

Open Source Folder

Output Mode dropdown

Transcription Mode dropdown

Input Audio dropdown

Output Text dropdown

Start Transcription / Start Batch Transcription button

Stop Transcription button

Open Output Folder button

Clear Status Window button

Close MediaScribe button

Status/progress window

Minimized support window

Sequential multi-file processing

Final batch results

Post-completion Source-folder refresh

Safe full-process-tree Stop behavior

Single-file cancellation

Full-batch abort

ABORTED_ incomplete-job folders

Stopped-operation exit code 2

UTF-8-safe filename/status output

The GUI calls the existing transcribe.ps1 backend.

The CLI remains available as a supported fallback.

Tested Multiple-File Checkpoint

The current GUI multiple-file implementation has passed an initial real-world test.

Confirmed behavior:

Several files were processed sequentially.

A mixed-language folder was processed with Input Audio set to Auto-detect.

English and Korean recordings were detected independently.

With Output Text set to Same as input / detected, the Korean recording produced Korean text.

Every file received its own output folder.

The existing single-file transcription engine continued to perform the normal work for each file.

This supports treating GUI Multiple-File Mode as implemented and initially tested rather than merely planned.

Implemented Stop Transcription Feature

Safe Stop Transcription is implemented and has passed single-file and multiple-file testing.

GUI Control Behavior

The GUI uses a separate Stop Transcription button beside the Start control.

While idle:

Start Transcription or Start Batch Transcription is enabled.

Stop Transcription is disabled and uses its normal inactive appearance.

While running:

Start is disabled.

Stop Transcription is enabled.

The active Stop button uses the existing section-title red with white bold text.

After Stop is confirmed:

Stop is disabled.

The button temporarily reads Stopping....

The GUI status changes to Stopped after the backend exits with code 2.

Confirmation Behavior

The confirmation explains that stopping will not create a finished transcript for the active file.

No, Keep Running is the safe/default choice.

The wording is conditional:

Single-file mode reports that MediaScribe is stopping the active transcription.

Batch mode reports that MediaScribe is stopping the active transcription and cancelling the remaining batch.

Full Process-Tree Stop

The GUI creates a unique temporary stop-request file and state file for each run.

The backend checks for the stop request while FFmpeg or Whisper is active.

Normal Stop behavior terminates the active FFmpeg, Python, and Whisper process tree while keeping the backend alive long enough to perform orderly cleanup.

The GUI also includes a forced full-tree fallback if normal stopping does not complete within the configured grace period.

Exit Codes

0 = completed successfully

1 = completed with errors

2 = stopped by user

Single-File Stop Behavior

In Selected file mode:

The active transcription is stopped.

The original source media remains unchanged.

The incomplete job folder is preserved.

The incomplete job folder is renamed with an ABORTED_ prefix and timestamp.

The GUI returns to an idle, usable state.

Multiple-File Stop Behavior

In All files in source folder mode:

The active file is stopped.

The entire remaining unstarted batch queue is cancelled.

Completed files remain completed.

The active original source media remains unchanged.

Unstarted source files remain untouched.

The active incomplete job folder is renamed with ABORTED_.

The batch does not skip the active file and continue.

The stopped-batch summary reports Files found, Completed, Failed, Stopped, and Not started.

ABORTED_ Safety and Cleanup

Only the active incomplete job-folder name receives the ABORTED_ prefix.

The original media filename is not changed.

Files inside the incomplete folder are not individually renamed.

Partial WAV audio, logs, and other incomplete output may be retained.

Previous completed jobs and the main Output folder are not deleted.

Example:

Output\ABORTED_grandma 80th birthday_20260723_205808

ABORTED_ folders may be reviewed, retained, or deleted by the user, library staff, or a Family History Center technician.

Tested Stop and Regression Checkpoint

Confirmed behavior:

Normal single-file transcription completes with exit code 0.

A complete mixed-language Auto-detect batch completes with exit code 0.

Single-file Stop returns exit code 2.

Batch Stop returns exit code 2.

Completed batch files remain completed.

Completed Input-folder originals move into their completed job folders.

The active stopped original remains in the Source/Input folder.

Unstarted batch files remain untouched.

The active incomplete folder receives the ABORTED_ prefix.

Stopped-batch counts correctly report Completed, Failed, Stopped, and Not started.

Accented filenames such as Rosé remain correct in GUI, backend, folder, and summary output.

PSScriptAnalyzer / VS Code reports no workspace problems after the completed changes.

Current Development Status

GUI Multiple-File Mode is implemented, tested, documented, and committed.

Safe Stop Transcription is implemented, tested, documented, and committed.

The CLI remains the supported fallback and existing terminal workflow.

The controlled Stop button is currently a GUI feature. The backend StopRequestFile design remains reusable by another launcher or future terminal control.

Recommended Next Development Sequence

Preserve the committed Stop checkpoint.

Update the current development snapshot so Stop moves from planned to implemented and tested.

Review setup.ps1 and installer copy lists to confirm the current README.md and Quick Start and Instructions.txt filenames.

Run clean-install and repair-install tests using the committed files.

Test the installed GUI and installed terminal fallback.

Review whether an Open Instructions GUI button would improve patron usability.

Consider media-duration display through FFprobe.

Add staff-facing cleanup guidance for ABORTED_ folders where appropriate.

Complete USB/extracted-ZIP packaging tests.

Create the next release-oriented snapshot.

Development Rules

Start from the current repository versions of MediaScribe-GUI.ps1 and transcribe.ps1.

Do not copy an older installed script over the repository without comparing changes.

Keep the current CLI, language, translation, UTF-8, file-safety, theme, refresh, and multiple-file behavior intact.

Keep processing sequential rather than parallel.

Preserve the original media unless the existing successful Input-folder movement rule applies.

Make targeted changes rather than unrelated refactors.

Preserve surrounding PowerShell try/catch blocks and braces during replacements.

Run PSScriptAnalyzer after script changes.

Commit after each stable stage.