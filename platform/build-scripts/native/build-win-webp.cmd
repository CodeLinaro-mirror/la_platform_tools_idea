@rem  Builds Windows WebP JNI library (x64 and ARM64)
@rem  Usage:
@rem   build-win-webp.cmd <out_dir> <dist_dir> <build_number>
@rem The binaries are built in <out_dir>, and webp_jni.dll artifacts copied to <dist_dir>\artifacts\windows-{x64,arm}

@setlocal enabledelayedexpansion

for %%F in ("%~1") do set OUT_DIR=%%~fF
for %%F in ("%~2") do set DIST_DIR=%%~fF
set BUILD_ID=%3
set SCRIPT_DIR=%~dp0
for %%F in ("%SCRIPT_DIR%..\..\..\..") do set TOP=%%~dpF
set CMAKE="C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake"
set JDK_11_0_x64=%TOP%prebuilts\studio\jdk\jni_headers\jdk11

set WIN_X64_DIR=%DIST_DIR%\artifacts\windows-x64
set WIN_ARM_DIR=%DIST_DIR%\artifacts\windows-arm
if not exist "%WIN_X64_DIR%" mkdir "%WIN_X64_DIR%"
if not exist "%WIN_ARM_DIR%" mkdir "%WIN_ARM_DIR%"

@rem if BUILD_ID is a number, pass it to cmake via BUILD_NUMBER
@rem BUILD_NUMBER is also set by ab/, so always override
IF 1%BUILD_ID% EQU +1%BUILD_ID% (set BUILD_NUMBER=%BUILD_ID%) else (set BUILD_NUMBER=)

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
cd /d "%OUT_DIR%"

if exist WinWebp-x64 rmdir /s /q WinWebp-x64
mkdir WinWebp-x64 && cd WinWebp-x64
%CMAKE% -A x64 "%SCRIPT_DIR%webp" || exit /b 1
%CMAKE% --build . --config Release -- -clp:ShowCommandLine || exit /b 1
copy /y "%OUT_DIR%\WinWebp-x64\bin\webp_jni.dll" "%WIN_X64_DIR%\webp_jni.dll" || exit /b 1
cd ..

if exist WinWebp-arm64 rmdir /s /q WinWebp-arm64
mkdir WinWebp-arm64 && cd WinWebp-arm64
%CMAKE% -A ARM64 "%SCRIPT_DIR%webp" || exit /b 1
%CMAKE% --build . --config Release -- -clp:ShowCommandLine || exit /b 1
copy /y "%OUT_DIR%\WinWebp-arm64\bin\webp_jni.dll" "%WIN_ARM_DIR%\webp_jni.dll" || exit /b 1
cd ..
