#!/bin/bash
set -eu

function realpath() {
   cd $1 && pwd
}

# Creates the directory if it does not exist and returns its absolute path
function make_target_dir() {
  mkdir -p "$1" && cd "$1" && pwd
}

declare -r top=$(realpath "$(dirname "$0")/../../../../..")
declare -r out_dir=$(make_target_dir "$1")
declare -r dist_dir=$(make_target_dir "$2")
declare -r build_number="$3"

declare -r linux_x64_dir=$(make_target_dir "$dist_dir/artifacts/linux-x64")
declare -r linux_arm_dir=$(make_target_dir "$dist_dir/artifacts/linux-arm")
declare -r win_x64_dir=$(make_target_dir "$dist_dir/artifacts/windows-x64")
declare -r win_arm_dir=$(make_target_dir "$dist_dir/artifacts/windows-arm")

if [[ "$*" == *"--quiet"* ]]
then
  verbose=
  quiet=1
else
  verbose=1
  quiet=
fi

# Converts version string to comparable number `12.3` -> 012003000000. Works for at most 4 fields
function ver { printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }

declare -r MAX_GLIBC_VERSION="2.31"
function verify_glibc() {
  glibc_version="$(readelf -V "$1" | grep -o "GLIBC_[0-9.]*" | sort -u | cut -d _ -f 2 | sort -V | tail -n 1)"
  if [ $(ver ${glibc_version:-0}) -gt $(ver $MAX_GLIBC_VERSION) ]; then
    echo "ERROR: $1 uses glibc version $glibc_version which is newer than $MAX_GLIBC_VERSION"
    exit 2
  fi
}

function verify_statically_linked() {
  if [[ ! -f "$1" ]]; then
    echo "ERROR: $1 Not found. Abort."
    exit 4
  fi

  if readelf -l "$1" | grep -q "INTERP"; then
    echo "ERROR: $1 have dynamically linked libraries. Abort."
    readelf -d "$1"
    exit 3
  fi
}

function verify_arch() {
  local file_path="$1"
  local expected_arch="$2"
  local file_output
  file_output="$(file -b "$file_path")"
  if [[ "$file_output" != *"$expected_arch"* ]]; then
    echo "ERROR: $file_path has unexpected architecture. Expected '$expected_arch', got: $file_output"
    exit 5
  fi
}

declare failed_count=0
declare failed_builds=""

(
    echo "---------------------------"
    echo " Building fsNotifier"
    echo "---------------------------"

    mkdir $out_dir/fsNotifier && cd $out_dir/fsNotifier
    cp -r $top/tools/idea/native/fsNotifier/linux/. ./

    ./make.sh
    verify_statically_linked fsnotifier
    verify_arch fsnotifier "x86-64"
    cp fsnotifier $linux_x64_dir/fsnotifier
    chmod +x $linux_x64_dir/fsnotifier
    ls -lha $linux_x64_dir/fsnotifier

    CC="clang --target=aarch64-linux-gnu" ./make.sh
    verify_statically_linked fsnotifier
    verify_arch fsnotifier "ARM aarch64"
    cp fsnotifier $linux_arm_dir/fsnotifier
    chmod +x $linux_arm_dir/fsnotifier
    ls -lha $linux_arm_dir/fsnotifier
) || { failed_builds+=" fsnotifier" ;  failed_count="$((failed_count+1))" ; }


(
    echo "---------------------------"
    echo " Building WslTools"
    echo "---------------------------"
    mkdir $out_dir/WslTools-x64 && cd $out_dir/WslTools-x64
    cp -r $top/tools/idea/native/WslTools/. ./

    # Prepare musl for WSL tools build (x64)
    cp /home/builder/musl-1.2.6.tar.gz ./
    tar xfz${verbose:+v} musl-1.2.6.tar.gz && mv musl-1.2.6 musl

    # ubuntu:14.04 have too old GCC version that use -std=c90 by default
    # and don't like `{0}` style initialization: https://stackoverflow.com/questions/1538943
    #
    # Update compiler flags, so that code compiles
    sed -i -e 's/CFLAGS =/CFLAGS = -std=c99 -Wno-missing-field-initializers -Wno-missing-braces /g' ./Makefile

    make MUSL_HOME="$out_dir/WslTools-x64/musl-install" LOG=${quiet:+warn} ${quiet:+-s}

    for tool in wslhash wslproxy ttyfix; do
      verify_statically_linked "$tool"
      verify_arch "$tool" "x86-64"
      cp "$tool" "$win_x64_dir/$tool"
      chmod +x "$win_x64_dir/$tool"
      ls -lha "$win_x64_dir/$tool"
    done

    mkdir $out_dir/WslTools-arm && cd $out_dir/WslTools-arm
    cp -r $top/tools/idea/native/WslTools/. ./

    # Prepare musl for WSL tools build (arm64)
    cp /home/builder/musl-1.2.6.tar.gz ./
    tar xfz${verbose:+v} musl-1.2.6.tar.gz && mv musl-1.2.6 musl
    (
      cd musl
      ./configure CC=aarch64-linux-gnu-gcc CROSS_COMPILE=aarch64-linux-gnu- \
        --prefix="$out_dir/WslTools-arm/musl-install" \
        --syslibdir="$out_dir/WslTools-arm/musl-install/lib"
      make ${quiet:+-s}
      make ${quiet:+-s} install
    )

    sed -i -e 's/CFLAGS =/CFLAGS = -std=c99 -Wno-missing-field-initializers -Wno-missing-braces /g' ./Makefile

    make MUSL_HOME="$out_dir/WslTools-arm/musl-install" LOG=${quiet:+warn} ${quiet:+-s}

    for tool in wslhash wslproxy ttyfix; do
      verify_statically_linked "$tool"
      verify_arch "$tool" "ARM aarch64"
      cp "$tool" "$win_arm_dir/$tool"
      chmod +x "$win_arm_dir/$tool"
      ls -lha "$win_arm_dir/$tool"
    done
) || { failed_builds+=" WslTools" ;  failed_count="$((failed_count+1))" ; }

(
  echo "---------------------------"
  echo " Building Restarter"
  echo "---------------------------"
  mkdir $out_dir/restarter && cd $out_dir/restarter
  cp -r $top/tools/idea/native/restarter/. ./

  export PATH="/home/builder/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/llvm-mingw/bin"
  export CARGO_HOME=/home/builder/.cargo
  export RUSTUP_HOME=/home/builder/.rustup

  cargo build ${verbose:+-v} --release --target x86_64-unknown-linux-musl --offline --target-dir "$out_dir/restarter"
  CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=aarch64-linux-gnu-gcc \
    cargo build ${verbose:+-v} --release --target aarch64-unknown-linux-musl --offline --target-dir "$out_dir/restarter"
  cargo build ${verbose:+-v} --release --target x86_64-pc-windows-gnu --offline --target-dir "$out_dir/restarter"
  CARGO_TARGET_AARCH64_PC_WINDOWS_GNULLVM_LINKER=aarch64-w64-mingw32-clang \
    CARGO_TARGET_AARCH64_PC_WINDOWS_GNULLVM_RUSTFLAGS="-C target-feature=+crt-static" \
    WINDRES=aarch64-w64-mingw32-windres \
    AR=aarch64-w64-mingw32-ar \
    cargo build ${verbose:+-v} --release --target aarch64-pc-windows-gnullvm --offline --target-dir "$out_dir/restarter"

  verify_statically_linked "$out_dir/restarter/x86_64-unknown-linux-musl/release/restarter"
  verify_arch "$out_dir/restarter/x86_64-unknown-linux-musl/release/restarter" "x86-64"
  verify_statically_linked "$out_dir/restarter/aarch64-unknown-linux-musl/release/restarter"
  verify_arch "$out_dir/restarter/aarch64-unknown-linux-musl/release/restarter" "ARM aarch64"
  verify_arch "$out_dir/restarter/x86_64-pc-windows-gnu/release/restarter.exe" "x86-64"
  verify_arch "$out_dir/restarter/aarch64-pc-windows-gnullvm/release/restarter.exe" "Aarch64"

  cp "$out_dir/restarter/x86_64-unknown-linux-musl/release/restarter" $linux_x64_dir/restarter
  cp "$out_dir/restarter/aarch64-unknown-linux-musl/release/restarter" $linux_arm_dir/restarter
  cp "$out_dir/restarter/x86_64-pc-windows-gnu/release/restarter.exe" $win_x64_dir/restarter.exe
  cp "$out_dir/restarter/aarch64-pc-windows-gnullvm/release/restarter.exe" $win_arm_dir/restarter.exe
  chmod +x $linux_x64_dir/restarter $linux_arm_dir/restarter
  ls -lha $linux_x64_dir/restarter $linux_arm_dir/restarter $win_x64_dir/restarter.exe $win_arm_dir/restarter.exe
) || { failed_builds+=" restarter" ;  failed_count="$((failed_count+1))" ; }

(
  echo "---------------------------"
  echo " Building Launcher"
  echo "---------------------------"

  mkdir $out_dir/launcher && cd $out_dir/launcher
  cp -r $top/tools/idea/native/XPlatLauncher/. ./

  export PATH="/home/builder/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/llvm-mingw/bin"
  export CARGO_HOME=/home/builder/.cargo
  export RUSTUP_HOME=/home/builder/.rustup

  cargo build ${verbose:+-v} --release --target x86_64-unknown-linux-gnu --offline --target-dir "$out_dir/launcher"
  CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc \
    cargo build ${verbose:+-v} --release --target aarch64-unknown-linux-gnu --offline --target-dir "$out_dir/launcher"
  cargo build ${verbose:+-v} --no-default-features --features "win_con" --release --target x86_64-pc-windows-gnu --offline --target-dir "$out_dir/launcher"
  CARGO_TARGET_AARCH64_PC_WINDOWS_GNULLVM_LINKER=aarch64-w64-mingw32-clang \
    CARGO_TARGET_AARCH64_PC_WINDOWS_GNULLVM_RUSTFLAGS="-C target-feature=+crt-static" \
    WINDRES=aarch64-w64-mingw32-windres \
    AR=aarch64-w64-mingw32-ar \
    cargo build ${verbose:+-v} --no-default-features --features "win_con" --release --target aarch64-pc-windows-gnullvm --offline --target-dir "$out_dir/launcher"
  cargo about generate about.hbs > $out_dir/launcher/launcher-licenses.html

  verify_glibc "$out_dir/launcher/x86_64-unknown-linux-gnu/release/xplat-launcher"
  verify_arch "$out_dir/launcher/x86_64-unknown-linux-gnu/release/xplat-launcher" "x86-64"
  verify_glibc "$out_dir/launcher/aarch64-unknown-linux-gnu/release/xplat-launcher"
  verify_arch "$out_dir/launcher/aarch64-unknown-linux-gnu/release/xplat-launcher" "ARM aarch64"
  verify_arch "$out_dir/launcher/x86_64-pc-windows-gnu/release/xplat-launcher.exe" "x86-64"
  verify_arch "$out_dir/launcher/x86_64-pc-windows-gnu/release/xplat-launcher-win-con.exe" "x86-64"
  verify_arch "$out_dir/launcher/aarch64-pc-windows-gnullvm/release/xplat-launcher.exe" "Aarch64"
  verify_arch "$out_dir/launcher/aarch64-pc-windows-gnullvm/release/xplat-launcher-win-con.exe" "Aarch64"

  cp "$out_dir/launcher/x86_64-unknown-linux-gnu/release/xplat-launcher" $linux_x64_dir/launcher
  cp "$out_dir/launcher/aarch64-unknown-linux-gnu/release/xplat-launcher" $linux_arm_dir/launcher
  cp "$out_dir/launcher/x86_64-pc-windows-gnu/release/xplat-launcher.exe" $win_x64_dir/launcher.exe
  cp "$out_dir/launcher/x86_64-pc-windows-gnu/release/xplat-launcher-win-con.exe" $win_x64_dir/launcher-win-con.exe
  cp "$out_dir/launcher/aarch64-pc-windows-gnullvm/release/xplat-launcher.exe" $win_arm_dir/launcher.exe
  cp "$out_dir/launcher/aarch64-pc-windows-gnullvm/release/xplat-launcher-win-con.exe" $win_arm_dir/launcher-win-con.exe

  for dir in "$linux_x64_dir" "$linux_arm_dir" "$win_x64_dir" "$win_arm_dir"; do
    cp $out_dir/launcher/launcher-licenses.html "$dir/xplat-launcher-third-party-licenses.html"
  done

  chmod +x $linux_x64_dir/launcher $linux_arm_dir/launcher
  ls -lha $linux_x64_dir/launcher $linux_arm_dir/launcher $win_x64_dir/launcher.exe $win_arm_dir/launcher.exe
) || { failed_builds+=" launcher" ;  failed_count="$((failed_count+1))" ; }

echo "=========================="
ls -lha $linux_x64_dir $linux_arm_dir $win_x64_dir $win_arm_dir
echo "=========================="

if [ $failed_count -gt 0 ]; then
  echo "Failed to build: $failed_builds"
  exit 4
else
  echo "Done Building IntelliJ Linux Tools!"
  exit 0
fi