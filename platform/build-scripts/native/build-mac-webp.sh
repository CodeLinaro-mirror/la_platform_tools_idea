#!/bin/sh

function usage() {
  declare -r prog="${0##*/}"
  cat <<EOF
Usage:
    $prog [-o <out_dir>] [-d <dist_dir>]
Builds macOS WebP JNI libraries (separate x86_64 and arm64 binaries).
Libraries are built in <out_dir> (or "out" if unset).
If <dist_dir> is set, artifacts are created at:
  <dist_dir>/mac-x64/libwebp_jni.dylib
  <dist_dir>/mac-arm/libwebp_jni.dylib
EOF
  exit 1
}

source $(dirname $0)/build-mac-common.sh

function verifySingleArch() {
  declare -r binary="$1"
  declare -r expected_arch="$2"
  if [ ! -f "$binary" ]; then
    echo "Failed to build $binary"
    exit 2
  fi
  declare -r archs=$(lipo -archs "$binary")
  echo "$binary archs: $archs"
  if [ "$archs" != "$expected_arch" ]; then
    echo "ERROR: $binary has unexpected arch '$archs' (expected '$expected_arch')"
    exit 3
  fi
}

declare -r jni_include="$top/prebuilts/studio/jdk/jni_headers/jdk11/include"

mkdir -p "$out_dir/x64"
(
  cd "$out_dir/x64"
  "$cmake_bin" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.14 \
    -DWEBP_DIR="$top/external/webp" \
    -DJNI_INCLUDE_DIR="$jni_include" \
    -DJNI_MD_INCLUDE_DIR="$jni_include/darwin" \
    "$script_dir/webp"
  "$cmake_bin" --build . --config Release --parallel 4
)
verifySingleArch "$out_dir/x64/bin/libwebp_jni.dylib" "x86_64"

mkdir -p "$out_dir/arm64"
(
  cd "$out_dir/arm64"
  "$cmake_bin" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
    -DWEBP_DIR="$top/external/webp" \
    -DJNI_INCLUDE_DIR="$jni_include" \
    -DJNI_MD_INCLUDE_DIR="$jni_include/darwin" \
    "$script_dir/webp"
  "$cmake_bin" --build . --config Release --parallel 4
)
verifySingleArch "$out_dir/arm64/bin/libwebp_jni.dylib" "arm64"

# Copy to Dist
[[ -n "${dist_dir:-}" ]] || exit 0
mkdir -p "$dist_dir/mac-x64" "$dist_dir/mac-arm"
cp "$out_dir/x64/bin/libwebp_jni.dylib" "$dist_dir/mac-x64/libwebp_jni.dylib"
cp "$out_dir/arm64/bin/libwebp_jni.dylib" "$dist_dir/mac-arm/libwebp_jni.dylib"
echo "Built $dist_dir/mac-x64/libwebp_jni.dylib and $dist_dir/mac-arm/libwebp_jni.dylib"
