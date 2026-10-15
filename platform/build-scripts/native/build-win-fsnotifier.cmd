@rem  Builds Android Studio Windows fsNotifier (x64 and ARM64)
@rem  Usage:
@rem   build-win-fsnotifier.cmd  <out_dir> <dist_dir> <build_number>
@rem The binaries are built in <out_dir>, and fsnotifier.exe artifacts copied to <dist_dir>\artifacts\windows-{x64,arm}

@setlocal enabledelayedexpansion

for %%F in ("%~1") do set OUT_DIR=%%~fF
for %%F in ("%~2") do set DIST_DIR=%%~fF
set BUILD_ID=%3
set SCRIPT_DIR=%~dp0
for %%F in ("%SCRIPT_DIR%..\..\..\..") do set TOP=%%~dpF
set CMAKE="C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake"

set WIN_X64_DIR=%DIST_DIR%\artifacts\windows-x64
set WIN_ARM_DIR=%DIST_DIR%\artifacts\windows-arm
if not exist "%WIN_X64_DIR%" mkdir "%WIN_X64_DIR%"
if not exist "%WIN_ARM_DIR%" mkdir "%WIN_ARM_DIR%"

@rem if BUILD_ID is a number, pass it to cmake via BUILD_NUMBER
@rem BUILD_NUMBER is also set by ab/, so always override
IF 1%BUILD_ID% EQU +1%BUILD_ID% (set BUILD_NUMBER=%BUILD_ID%) else (set BUILD_NUMBER=)

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
cd /d "%OUT_DIR%"

if exist WinFsNotifier-x64 rmdir /s /q WinFsNotifier-x64
mkdir WinFsNotifier-x64 && cd WinFsNotifier-x64
%CMAKE% -A x64 "%TOP%tools\idea\native\WinFsNotifier" || exit /b 1
%CMAKE% --build . --config Release -- -clp:ShowCommandLine || exit /b 1
copy /y "%OUT_DIR%\WinFsNotifier-x64\Release\fsnotifier.exe" "%WIN_X64_DIR%\fsnotifier.exe" || exit /b 1
cd ..

if exist WinFsNotifier-arm64 rmdir /s /q WinFsNotifier-arm64
mkdir WinFsNotifier-arm64 && cd WinFsNotifier-arm64
%CMAKE% -A ARM64 "%TOP%tools\idea\native\WinFsNotifier" || exit /b 1
%CMAKE% --build . --config Release -- -clp:ShowCommandLine || exit /b 1
copy /y "%OUT_DIR%\WinFsNotifier-arm64\Release\fsnotifier.exe" "%WIN_ARM_DIR%\fsnotifier.exe" || exit /b 1
cd ..