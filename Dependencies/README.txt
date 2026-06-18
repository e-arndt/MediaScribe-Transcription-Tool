MediaScribe Dependencies Folder

This folder is used for optional bundled dependencies that can be copied or installed by setup.ps1.

MediaScribe can use existing system dependencies if they are already installed, but this folder allows the package to include common dependency files for easier setup on a new Windows PC.

============================================================
FFMPEG
============================================================

Bundled FFmpeg files should be placed here:

Dependencies\FFmpeg\

Expected files:

ffmpeg.exe
ffprobe.exe

During setup, these files are copied into the installed MediaScribe runtime folder:

Tools\ffmpeg\

The installed runtime path should become:

Tools\ffmpeg\ffmpeg.exe
Tools\ffmpeg\ffprobe.exe

MediaScribe looks for FFmpeg in this order:

1. Local Tools\ffmpeg\ffmpeg.exe
2. System FFmpeg from PATH

If bundled FFmpeg is present, MediaScribe should not need system FFmpeg from PATH.

============================================================
PYTHON
============================================================

A bundled Python installer may be placed here:

Dependencies\Python\

Example installer name:

python-3.13.7-amd64.exe

If Python is missing, setup.ps1 can offer to run the bundled Python installer.

The bundled Python installer is intended to install Python for the current user with pip enabled.

Python is checked before pip and Whisper.

============================================================
PIP
============================================================

pip is handled through Python.

There is no separate pip dependency folder.

If Python is available but pip is missing, setup.ps1 can try to repair pip with:

python -m ensurepip --upgrade

============================================================
OPENAI WHISPER
============================================================

OpenAI Whisper is not stored directly in this folder.

If Python and pip are available, setup.ps1 checks whether Whisper is installed.

If Whisper is missing, setup.ps1 can offer to install it with pip:

python -m pip install -U openai-whisper

Installing Whisper requires internet access.

If internet access is not available, setup may finish with missing dependencies. After fixing internet access, run Install.bat again.

============================================================
EXPECTED DEPENDENCY ORDER
============================================================

setup.ps1 checks dependencies in this order:

1. Python
2. pip
3. OpenAI Whisper
4. FFmpeg

Dependencies are handled independently and sequentially.

No two dependency installs should run at the same time.

============================================================
NOTES
============================================================

Install.bat is used from the package, USB, download, or extracted ZIP folder.

MediaScribe.bat is used from the installed MediaScribe folder after setup.

The Dependencies folder is part of the package/workspace, not the normal daily-use installed workflow.

Normal users should not need to edit this folder unless they are rebuilding or repairing the install package.