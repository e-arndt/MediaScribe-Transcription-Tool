MediaScribe

MediaScribe is a local Windows transcription tool that creates transcripts, English translations, and optional caption files from audio and video recordings.

It uses:

FFmpeg to extract and normalize audio.

OpenAI Whisper to create transcripts, translations, and caption data.

PowerShell for installation, the transcription engine, the terminal interface, and the WinForms GUI.

MediaScribe provides two supported interfaces:

MediaScribe GUI — recommended for most users and Family History Center patrons.

MediaScribe Terminal — intended for advanced users, fallback, development, and troubleshooting.

The central development rule remains:

Do not break the CLI.

The GUI and Terminal interfaces both call the same transcribe.ps1 backend so that transcription logic, file safety, language support, output verification, failure handling, and Stop behavior remain consistent.

Current feature summary

The current version includes:

GUI single-file transcription.

GUI sequential multiple-file transcription.

Terminal single-file and Input-folder batch transcription.

Default and Full output modes.

Fast and Accurate transcription modes.

English, Auto-detect, and selected non-English source languages.

Same-language transcription and English translation.

Live English transcript progress in approximately 30-second Whisper chunks.

Hidden-preview UTF-8 logging for Auto-detect, non-English, and translation jobs.

Separate output folders for every processed file.

Safe movement of Input-folder originals only after successful output verification.

Automatic GUI Source-list refresh after processing.

Resizable GUI Status section.

Safe GUI Stop for single files and complete batches.

Safe interactive Terminal Stop using the S key.

Full active process-tree termination for FFmpeg, Python, and Whisper.

ABORTED_ folders for incomplete user-stopped jobs.

Distinct successful, failed, stopped, and not-started batch states.

Exit codes 0, 1, and 2.

UTF-8-safe filenames and console output.

Single-instance GUI protection with a foreground warning.

Automatic removal of truly empty failed job folders.

Continued batch processing after an individual file failure.

Preserved advanced Terminal/CLI fallback.

Intended use

MediaScribe is useful for many audio and video transcription needs. A major intended use is genealogy and Family History Center work.

Examples include:

8mm and Super 8 film

VHS and VHS-C

Video8 and Hi8

Audio cassette

Reel-to-reel tape

Family interviews

Home movie narration

Oral histories

Family stories

Funeral and memorial recordings

Church talks and lessons

Meetings and discussions

Dictation

Other spoken media

After analog media is digitized into a supported audio or video file, MediaScribe can create a searchable written transcript.

Recommended user flow

Normal users should not need to run long PowerShell commands.

Download / USB / Desktop / extracted ZIP
    -> Install.bat
    -> setup.ps1
    -> installed MediaScribe folder
    -> Start-MediaScribe-GUI.bat
    -> MediaScribe-GUI.ps1
    -> transcribe.ps1

The GUI is recommended for daily use.

The Terminal version remains available through:

MediaScribe.bat

or:

Start-MediaScribe.bat

depending on the package.

Installation

Open the folder where MediaScribe was downloaded, extracted, or copied and double-click:

Install.bat

The installer starts setup.ps1, asks where to install MediaScribe, and normally defaults to:

Documents\MediaScribe

Setup creates the application folders, copies the current scripts and documentation, and checks required dependencies.

When setup completes successfully, it may offer:

[1] Start MediaScribe GUI
[2] Start MediaScribe Terminal
[3] Open Instructions
[Q] Quit setup

Choose the GUI for normal use.

Reinstall and repair

Run Install.bat again to reinstall or repair MediaScribe.

Setup may replace core files, including:

transcribe.ps1

MediaScribe-GUI.ps1

README.md

Quick Start and Instructions.txt

MediaScribe.bat

Start-MediaScribe-GUI.bat

config.json

Setup recreates missing required folders but does not clear the contents of:

Input

Output

Logs

Models

Tools

Existing media, transcripts, captions, WAV files, logs, and models should remain intact.

To uninstall MediaScribe, delete the installed MediaScribe folder.

Installed folder

A typical installed folder looks like:

MediaScribe\
├── Input\
├── Output\
├── Logs\
├── Models\
├── Tools\
│   └── ffmpeg\
│       ├── ffmpeg.exe
│       └── ffprobe.exe
├── config.json
├── MediaScribe-GUI.ps1
├── MediaScribe.bat
├── Quick Start and Instructions.txt
├── README.md
├── Start-MediaScribe-GUI.bat
└── transcribe.ps1

The local FFmpeg files are present when bundled FFmpeg was included and copied during setup.

Start MediaScribe

For normal GUI use:

Start-MediaScribe-GUI.bat

For Terminal fallback:

MediaScribe.bat

or:

Start-MediaScribe.bat

Install.bat is for installation, reinstallation, and repair. Use the GUI or Terminal launcher after installation.

Developer/workspace launch

From the project workspace:

.\Start-MediaScribe-GUI.bat

.\Start-MediaScribe.bat

Direct GUI launch:

powershell -NoProfile -ExecutionPolicy Bypass -File .\MediaScribe-GUI.ps1

Direct Terminal launch:

powershell -NoProfile -ExecutionPolicy Bypass -File .\transcribe.ps1

Direct PowerShell commands are mainly for development and testing.

Dependencies

MediaScribe requires:

Python

pip

OpenAI Whisper

FFmpeg

Setup checks these dependencies.

FFmpeg

Bundled FFmpeg may be placed in:

Dependencies\FFmpeg

Setup copies it to:

Tools\ffmpeg

Lookup order:

Tools\ffmpeg\ffmpeg.exe

System ffmpeg available through PATH

Python

A bundled installer may be placed in:

Dependencies\Python

If Python is missing, setup can offer to run the bundled installer.

pip

If Python exists but pip is missing, setup can try:

python -m ensurepip --upgrade

OpenAI Whisper

Whisper is installed through pip if missing. Installation requires internet access.

Whisper lookup order:

python -m whisper

Global whisper.exe or whisper command

MediaScribe prefers the Python module route because it is more dependable on Windows and avoids some application-control issues associated with generated launcher executables.

Supported input formats

Video:

MP4, MKV, MOV, M4V, AVI, WEBM

Audio:

MP3, M4A, WAV, AAC, FLAC, OGG, OPUS, WMA

DRM-protected, unsupported, damaged, or incorrectly named media may fail.

Output modes

Default

Recommended for most users:

Original media

Mono 16 kHz WAV audio

TXT transcript

GUI wording:

Default - Original file, WAV audio, TXT transcript

Full

Creates:

Original media

WAV audio

TXT transcript

SRT subtitle file

VTT subtitle file

TSV timing data

JSON Whisper output

GUI wording:

Full - Original file, WAV audio, TXT, SRT, VTT, TSV, JSON

Use SRT or VTT for caption and subtitle workflows.

Transcription modes

Fast

Fast is recommended and uses the configured default Whisper model.

Current default:

medium

Accurate

Accurate uses the large Whisper model. It may help with difficult audio but requires more processing time and resources.

Input Audio and Output Text

MediaScribe separates spoken-language selection from output-language behavior.

Input Audio

Available options include:

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

Use Auto-detect when the spoken language is unknown or when a batch contains different languages. Auto-detect evaluates each file independently.

Selecting a specific language applies that language to every file in a batch.

Output Text

Options:

Same as input / detected — creates text in the source or detected language.

English translation — asks Whisper to translate supported speech into English.

Whisper translation targets English. MediaScribe does not currently translate into arbitrary destination languages.

Recommended mixed-language settings:

Input Audio: Auto-detect
Output Text: Same as input / detected

To create English output from each recording:

Input Audio: Auto-detect
Output Text: English translation

A tested mixed English/Korean batch correctly produced English text for English recordings and Korean text for Korean audio when Same as input / detected was selected.

GUI overview

The GUI includes:

Source folder field

Selected file dropdown

Selected file / All files in source folder controls

Browse Folder

Refresh Files

Open Source Folder

Output Mode

Transcription Mode

Input Audio

Output Text

Status

Start Transcription / Start Batch Transcription

Stop Transcription

Open Output Folder

Clear Status Window

Close MediaScribe

The Status group and status textbox expand when the GUI window is resized. The upper controls retain their compact layout, and the Close button remains centered near the bottom.

After a single job or batch, the Source list refreshes.

GUI support window

The GUI runs inside a PowerShell host. A minimized support window may appear with the title:

DO NOT CLOSE - MediaScribe Support Window

Do not close this window while MediaScribe is running. Close MediaScribe from the GUI.

The GUI also blocks normal closing while transcription is active. Use Stop first, then close after MediaScribe returns to idle.

Single-instance GUI protection

Only one MediaScribe GUI instance may run in the current Windows logon session.

The GUI uses the named mutex:

Local\MediaScribe.GUI.SingleInstance

A duplicate launch displays a foreground warning:

MediaScribe is already running.

Check the taskbar for the open MediaScribe window.
Only one MediaScribe GUI instance can run at a time.

The warning uses a temporary TopMost owner window so it remains visible above the newly opened PowerShell support window.

After the user acknowledges the warning, the duplicate process exits. The original GUI continues running.

This protection applies only to the GUI. It does not block the backend process intentionally launched by the GUI or prevent an advanced user from opening the Terminal version.

Source folders and file selection

The GUI defaults to the configured Input folder but can browse to a USB drive, Downloads folder, Desktop folder, external drive, or another media folder.

Users may process:

One selected file.

All recognized files in the Source folder.

Multiple-file mode captures the recognized list before processing and runs files sequentially. It never launches multiple Whisper jobs in parallel.

The same settings apply to every file in a batch:

Output mode

Model/transcription mode

Input Audio

Output Text/task

Each file receives its own output folder and its own file-safety decision.

Live preview behavior

Live preview is enabled when:

Input Audio: English
Output Text: Same as input / detected

Python and Whisper run with unbuffered output:

PYTHONUNBUFFERED=1
python -u -m whisper

Whisper normally processes and releases transcript progress in approximately 30-second audio windows. Several timestamped lines may therefore appear together after each window completes.

Live preview is intentionally hidden for:

Auto-detect

Non-English input languages

English translation

The final transcript is still created.

Hidden-preview jobs may save:

whisper_stdout.log
whisper_stderr.log

These log files are normal and keep non-English or translation output out of the Windows status display.

Processing architecture

For each file, transcribe.ps1:

Resolves and validates the source.

Creates a unique job folder.

Extracts mono 16 kHz WAV audio with FFmpeg.

Runs Whisper.

Verifies the expected transcript output.

Moves or copies the original according to configuration.

Returns a structured success, failure, or stopped result.

The batch wrapper reuses this single-file engine:

Capture recognized files.

Process one file.

Wait for completion.

Record the result.

Continue after an individual failure.

Stop the full queue after a confirmed Stop.

Display final counts.

This keeps GUI and Terminal behavior aligned and avoids duplicated transcription logic.

GUI Stop behavior

While idle:

Start is enabled.

Stop is disabled.

While running:

Start is disabled.

Stop is enabled.

Stop uses the existing red section-title color with white bold text.

After confirmation:

Stop becomes disabled.

The label changes to Stopping....

The backend stops the active FFmpeg, Python, and Whisper process tree.

The GUI returns to an idle state.

The default confirmation is No, Keep Running.

Single-file GUI Stop

Active processing stops.

Original source remains unchanged.

Incomplete job folder receives an ABORTED_ prefix and timestamp.

GUI returns to idle.

Backend returns exit code 2.

GUI batch Stop

Completed files remain complete.

Active file stops.

Active original remains unchanged.

Active incomplete folder receives ABORTED_.

Remaining files do not start.

Unstarted originals remain untouched.

Summary reports Completed, Failed, Stopped, and Not started.

Backend returns exit code 2.

The GUI uses a unique temporary Stop-request file and state file for each run. It also includes a forced process-tree fallback if cooperative stopping does not complete within the configured grace period.

Terminal interface

The Terminal interface is colored and intentionally remains useful for advanced users and troubleshooting.

File menu example:

[1] First file.mp4
[2] Second file.mp3
[B] Process all files
[Q] Quit

Settings include:

[D] Default
[F] Full

[F] Fast
[A] Accurate

Input Audio:

[E] English
[A] Auto-detect
[C] Chinese
[F] French
[G] German
[I] Italian
[J] Japanese
[K] Korean
[P] Portuguese
[S] Spanish

Output Text:

[S] Same as input / detected
[E] English translation

Auto-detect should be selected for a mixed-language batch.

Terminal safe Stop

During active processing, the Terminal displays:

[S] Stop transcription safely

For a batch:

[S] Stop transcription safely and cancel the remaining batch

Pressing S opens a confirmation:

[Y] Yes, stop
[N] No, keep running
Default: No, keep running

Press Y to stop. Press N or Enter to continue.

The child-process wait loop polls for the Stop key while FFmpeg or Whisper is active. A confirmed Stop remains classified as stopped even if the child process happens to finish while the confirmation is being answered.

Terminal single-file Stop

Active original remains unchanged.

Incomplete job folder receives ABORTED_.

Result is [STOPPED].

Terminal returns to the Next Step menu.

Terminal batch Stop

Completed files remain completed.

Active file is stopped.

Active original remains unchanged.

Active folder receives ABORTED_.

Remaining files do not start.

Summary reports Completed, Failed, Stopped, and Not started.

Use the controlled S option instead of Ctrl+C whenever possible.

Terminal status colors

The Terminal interface uses a consistent color language.

Green:

[OK]

Used for successful files and completed counts.

Yellow:

[WARN]
[STOPPED]
[NOT STARTED]

Used for warnings, attention, user-stopped work, and unstarted files.

Red:

[ERROR]
[FAILED]

Used for actual processing failures.

General information uses the normal console color.

Exit codes

0 = completed successfully
1 = completed with errors
2 = stopped by user

A stopped batch returns 2 even when an earlier file failed.

Output folders

Each file receives a separate folder:

Output\My Recording

Default example:

Output\My Recording\
├── My Recording.mp4
├── My Recording.wav
└── My Recording.txt

Full example:

Output\My Recording\
├── My Recording.mp4
├── My Recording.wav
├── My Recording.txt
├── My Recording.srt
├── My Recording.vtt
├── My Recording.tsv
└── My Recording.json

If the normal folder already exists, MediaScribe creates a timestamped sibling instead of overwriting the existing job.

File safety

Files inside Input are moved into the completed job folder only after expected output verification.

External source files are left in place by default.

Per-file behavior:

Successful Input-folder file → moved into completed job folder.

Failed Input-folder file → remains in Input.

Stopped active file → remains in Source/Input.

Unstarted batch file → remains untouched.

External source file → remains in the external folder by default.

These rules apply independently to every file.

Failure handling

A processing failure is distinct from a user Stop.

Failed items are shown as [FAILED] in red.

A batch continues after an individual failure.

Failed originals remain untouched.

Failed items contribute to the Failed count.

A batch with failures and no Stop returns exit code 1.

Empty failed-folder cleanup

When FFmpeg fails before creating useful output, MediaScribe checks the job folder.

A truly empty folder is removed automatically.

The folder is retained when it contains anything, including:

Partial WAV data

Whisper logs

Transcript fragments

Diagnostic files

Hidden files

When an empty failed folder is removed, the general Output folder is used as the safe Open-folder target.

ABORTED_ folders

ABORTED_ is reserved for confirmed user Stop operations.

Example:

Output\ABORTED_Family Interview_20260723_205808

The original media filename is not changed. Files inside the partial folder are not individually renamed.

ABORTED_ folders may contain useful incomplete WAV audio, logs, or output and can be reviewed, retained, or deleted.

Configuration

MediaScribe reads config.json.

Example:

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

Important fields:

AppName — displayed application name.

BaseFolder — installed application root.

InputFolder — default Source/Input folder.

OutputFolder — results and job folders.

LogsFolder — log support.

ModelsFolder — model support.

DefaultModel — default Whisper model.

DefaultLanguage — default spoken language.

OutputMode — default or full.

MoveInputFolderFilesAfterProcessing — moves successful Input-folder originals after output verification.

ExternalFileArchiveBehavior — normally LeaveOriginalInPlace; may also support CopyToJobFolder.

Parameter-mode backend

The GUI calls transcribe.ps1 in non-interactive parameter mode.

Single-file parameters include:

-InputFile <path>
-OutputMode default|full
-Model medium|large
-Language en|auto|<Whisper language code>
-Task transcribe|translate
-StopRequestFile <temporary path>
-StateFile <temporary JSON path>

The backend also supports non-interactive folder/batch processing used by the GUI while preserving the separate interactive Terminal workflow.

StopRequestFile and StateFile provide cooperative GUI cancellation, active-stage tracking, orderly cleanup, and forced process-tree fallback support.

Confirmed test checkpoint

The current implementation has been tested with:

Normal GUI single-file transcription.

Normal Terminal single-file transcription.

English live preview in approximately 30-second chunks.

Complete GUI and Terminal batches.

Mixed English/Korean Auto-detect batch.

Korean same-language transcript output.

GUI single-file Stop.

GUI batch Stop.

Terminal single-file Stop.

Terminal batch Stop.

Stop cancellation/default No behavior.

Completed-file preservation.

Active-source preservation.

Unstarted-source preservation.

ABORTED_ folder handling.

UTF-8 filenames, including Rosé.

Single-instance GUI blocking.

Foreground duplicate-instance warning.

Recoverable FFmpeg decoder warnings.

Deliberately invalid media failure.

Batch continuation after failure.

Red [FAILED] status.

Green completed count.

Yellow stopped and not-started status.

Empty failed-folder removal.

Exit codes 0, 1, and 2.

A representative stopped batch successfully reported completed, failed, stopped, and not-started items while preserving the correct originals and completed output folders.

Current development status

Implemented, tested, documented, and committed:

GUI multiple-file mode.

GUI safe Stop.

Terminal safe Stop.

Terminal Input Audio choices.

Terminal Output Text choices.

Auto-detect mixed-language batches.

Unbuffered live preview.

Single-instance GUI mutex.

Foreground duplicate-instance warning.

Resizable Status section.

Colored CLI summary states.

Failed-file continuation.

Empty failed-folder cleanup.

UTF-8 filename handling.

File-safety and ABORTED_ behavior.

The GUI remains recommended for normal users. The Terminal remains a supported advanced fallback.

Recommended next development sequence

Preserve the current committed checkpoint.

Run PSScriptAnalyzer on the current scripts.

Update the full development snapshot.

Review setup.ps1 and installer copy lists for the current filenames.

Run clean-install and repair-install tests.

Test the installed GUI and installed Terminal version.

Complete USB/extracted-ZIP packaging tests.

Consider an Open Instructions GUI button.

Consider media-duration display through FFprobe.

Add staff-facing cleanup guidance where useful.

Prepare the next release-oriented snapshot.

Development rules

Start from the current repository versions of MediaScribe-GUI.ps1 and transcribe.ps1.

Do not replace repository files with older installed copies without comparing them.

Preserve CLI behavior while improving the GUI.

Keep processing sequential rather than parallel.

Preserve language, translation, UTF-8, file-safety, theme, refresh, multiple-file, and Stop behavior.

Preserve the original media unless the successful Input-folder movement rule applies.

Keep user-requested Stop distinct from processing failure.

Make targeted changes instead of unrelated refactors.

Preserve surrounding PowerShell try/catch blocks and braces during replacements.

Run PSScriptAnalyzer after script changes.

Test GUI and Terminal paths after shared backend changes.

Commit after each stable stage.