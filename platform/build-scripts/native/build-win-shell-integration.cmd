@rem  Builds Windows Shell integration library (x64 and ARM64)
@rem  Usage:
@rem   build-win-shell-integration.cmd  <out_dir> <dist_dir> <build_number>
@rem The binaries are built in <out_dir>, and WinShellIntegrationBridge.dll artifacts copied to <dist_dir>\artifacts\windows-{x64,arm}

setlocal enabledelayedexpansion

for %%F in ("%~1") do set OUT_DIR=%%~fF
for %%F in ("%~2") do set DIST_DIR=%%~fF
set BUILD_ID=%3
set SCRIPT_DIR=%~dp0
for %%F in ("%SCRIPT_DIR%..\..\..\..") do set TOP=%%~dpF
set CMAKE="C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake"
set JDK_11_0_x64=%TOP%prebuilts\studio\jdk\jni_headers\jdk11\

set WIN_X64_DIR=%DIST_DIR%\artifacts\windows-x64
set WIN_ARM_DIR=%DIST_DIR%\artifacts\windows-arm
if not exist "%WIN_X64_DIR%" mkdir "%WIN_X64_DIR%"
if not exist "%WIN_ARM_DIR%" mkdir "%WIN_ARM_DIR%"

@rem if BUILD_ID is a number, pass it to cmake via BUILD_NUMBER
@rem BUILD_NUMBER is also set by ab/, so always override
IF 1%BUILD_ID% EQU +1%BUILD_ID% (set BUILD_NUMBER=%BUILD_ID%) else (set BUILD_NUMBER=)
set PATH=%JDK_11_0_x64%include;%PATH%

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
cd /d "%OUT_DIR%"

if exist WinShellIntegration-x64 rmdir /s /q WinShellIntegration-x64
mkdir WinShellIntegration-x64 && cd WinShellIntegration-x64
%CMAKE% -A x64 "%TOP%tools\idea\native\WinShellIntegration" || exit /b 1
%CMAKE% --build . --config Release -- -clp:ShowCommandLine || exit /b 1
copy /y "%OUT_DIR%\WinShellIntegration-x64\src\winshellintegrationbridge\Release\WinShellIntegrationBridge64.dll" "%WIN_X64_DIR%\WinShellIntegrationBridge.dll" || exit /b 1
cd ..

if exist WinShellIntegration-arm64 rmdir /s /q WinShellIntegration-arm64
mkdir WinShellIntegration-arm64 && cd WinShellIntegration-arm64
%CMAKE% -A ARM64 "%TOP%tools\idea\native\WinShellIntegration" || exit /b 1
%CMAKE% --build . --config Release -- -clp:ShowCommandLine || exit /b 1
copy /y "%OUT_DIR%\WinShellIntegration-arm64\src\winshellintegrationbridge\Release\WinShellIntegrationBridge64a.dll" "%WIN_ARM_DIR%\WinShellIntegrationBridge.dll" || exit /b 1
cd ..