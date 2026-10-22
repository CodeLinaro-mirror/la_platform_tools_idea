# IntelliJ Native Tools Build Scripts

Scripts and container definitions for building IntelliJ Platform native tools used by Android Studio across Linux, Windows, and macOS (`x64` and `ARM64`).

- **Native source code**: `tools/idea/native/`
- **Checked-in prebuilt destinations**:
  - `tools/idea/bin/{linux,win}/{amd64,aarch64}/` and `tools/idea/bin/mac/`
  - `tools/idea/platform/build-scripts/resources/{linux,win}/{amd64,aarch64}/` and `tools/idea/platform/build-scripts/resources/mac/`
- **Busytown CI branch config**: `google3/configs/wireless/android/busytown/apps/git_studio/git_studio-intellij.gcl` (`git_studio-intellij`)
- **Prebuilt drop tool**: `google3/wireless/android/devtools/studio/prebuilt_drop/`

---

## 1. Overview & Artifact Layout

All three CI targets (`IntelliJ-linux`, `IntelliJ-win`, `IntelliJ-mac_arm64`) organize their build outputs under `<dist_dir>/artifacts/`:

```text
<dist_dir>/artifacts/
├── linux-x64/
├── linux-arm/
├── windows-x64/
├── windows-arm/
└── mac/
```

| Tool | Source (`tools/idea/native/`) | CI Target (Entry Script) | Build Artifact Path (`<dist_dir>/artifacts/...`) | Checked-In Repo Path (`tools/idea/...`) |
| :--- | :--- | :--- | :--- | :--- |
| **fsnotifier** (Linux) | `fsNotifier/linux` | `IntelliJ-linux` (`linux_tools_re_proxy.sh`) | `linux-{x64,arm}/fsnotifier` | `bin/linux/{amd64,aarch64}/fsnotifier` |
| **restarter** (Linux) | `restarter` | `IntelliJ-linux` (`linux_tools_re_proxy.sh`) | `linux-{x64,arm}/restarter` | `platform/build-scripts/resources/linux/{amd64,aarch64}/restarter` |
| **XPlatLauncher** (Linux) | `XPlatLauncher` | `IntelliJ-linux` (`linux_tools_re_proxy.sh`) | `linux-{x64,arm}/{launcher,xplat-launcher-third-party-licenses.html}` | `platform/build-scripts/resources/linux/{amd64,aarch64}/{launcher,launcher_licenses.html}` |
| **WslTools** (`wslhash`, `wslproxy`, `ttyfix`) | `WslTools` | `IntelliJ-linux` (`linux_tools_re_proxy.sh`) | `windows-{x64,arm}/{wslhash,wslproxy,ttyfix}` | `bin/win/{amd64,aarch64}/{wslhash,wslproxy,ttyfix}` |
| **restarter** (Windows) | `restarter` | `IntelliJ-linux` (`linux_tools_re_proxy.sh`) | `windows-{x64,arm}/restarter.exe` | `platform/build-scripts/resources/win/{amd64,aarch64}/restarter.exe` |
| **XPlatLauncher** (Windows) | `XPlatLauncher` | `IntelliJ-linux` (`linux_tools_re_proxy.sh`) | `windows-{x64,arm}/{launcher.exe,launcher-win-con.exe,xplat-launcher-third-party-licenses.html}` | `platform/build-scripts/resources/win/{amd64,aarch64}/{launcher.exe,launcher-win-con.exe,launcher_licenses.html}` |
| **WinFsNotifier** | `WinFsNotifier` | `IntelliJ-win` (`native_win.cmd`) | `windows-{x64,arm}/fsnotifier.exe` | `bin/win/{amd64,aarch64}/fsnotifier.exe` |
| **WinProcessListHelper** | `WinProcessListHelper` | `IntelliJ-win` (`native_win.cmd`) | `windows-{x64,arm}/WinProcessListHelper.exe` | `bin/win/{amd64,aarch64}/WinProcessListHelper.exe` |
| **WinShellIntegration** | `WinShellIntegration` | `IntelliJ-win` (`native_win.cmd`) | `windows-{x64,arm}/WinShellIntegrationBridge.dll` | `bin/win/{amd64,aarch64}/WinShellIntegrationBridge.dll` |
| **fsnotifier** (macOS) | `fsNotifier/mac` | `IntelliJ-mac_arm64` (`native_mac.sh`) | `mac/fsnotifier` | `bin/mac/fsnotifier` |
| **MacEnvReader** | `MacEnvReader` | `IntelliJ-mac_arm64` (`native_mac.sh`) | `mac/printenv` | `bin/mac/printenv` |
| **MacScreenMenu** | `MacScreenMenu` | `IntelliJ-mac_arm64` (`native_mac.sh`) | `mac/libmacscreenmenu64.dylib` | `bin/mac/libmacscreenmenu64.dylib` |
| **MacTouchBar** | `MacTouchBar` | `IntelliJ-mac_arm64` (`native_mac.sh`) | `mac/libnst64.dylib` | `bin/mac/libnst64.dylib` |
| **restarter** (macOS) | `restarter` | `IntelliJ-mac_arm64` (`native_mac.sh`) | `mac/restarter` | `platform/build-scripts/resources/mac/restarter` |
| **XPlatLauncher** (macOS) | `XPlatLauncher` | `IntelliJ-mac_arm64` (`native_mac.sh`) | `mac/xplat-launcher` | `platform/build-scripts/resources/mac/launcher` |

> **Note on `WslTools`**: `wslhash`, `wslproxy`, and `ttyfix` are statically linked Linux `musl` ELF binaries (`x86_64` and `aarch64`), but they are placed under `artifacts/windows-{x64,arm}/` because they ship inside the Windows IDE distribution (`bin/win/{amd64,aarch64}/`) and are executed by the Windows IDE inside the user's WSL distribution.

> **Note on `WinElevator` (`elevator.exe` and `bin/win/.../launcher.exe`)**: `tools/idea/native/WinElevator` is intentionally **not** built by these scripts or dropped via `prebuilt_drop`. Android Studio uses the prebuilt `elevator.exe` and `launcher.exe` binaries in `bin/win/{amd64,aarch64}/` as-is from JetBrains (signed by JetBrains). Do not add `WinElevator` to `native_win.cmd`. (Note that `bin/win/.../launcher.exe` is the UAC elevation helper for `elevator.exe`, distinct from the main IDE launcher `platform/build-scripts/resources/win/.../launcher.exe` built from `XPlatLauncher`.)

---

## 2. How Each Platform Build Works

### Linux & Cross-Compiled Windows Rust Tools (`IntelliJ-linux`)

The `IntelliJ-linux` target runs on Remote Build Execution (RBE) inside a pinned Ubuntu 20.04 Docker container:

1. **`linux_tools_re_proxy.sh <out_dir> <dist_dir> <build_number>`**:
   - Starts the RBE `bootstrap` daemon (`prebuilts/remoteexecution-client/live/bootstrap`).
   - Invokes `rewrapper` with `android-studio.cfg` (which pins the container image digest `gcr.io/google.com/android-studio-alphasource/intellij_native@sha256:...` and declares all inputs/outputs) to execute `linux_tools.sh` remotely inside the container.
   - Shuts down `bootstrap` and copies RBE logs into `<dist_dir>`.
2. **`linux_tools.sh`**:
   - **`fsnotifier`**: Compiled with `clang` (`linux-x64`) and `clang --target=aarch64-linux-gnu` (`linux-arm`) against Ubuntu 20.04 glibc headers so the resulting binaries maintain a low `GLIBC_2.*` symbol requirement.
   - **`WslTools` (`wslhash`, `wslproxy`, `ttyfix`)**: Builds `musl-1.2.6` from `/home/builder/musl-1.2.6.tar.gz` for both `x86_64` and `aarch64` and compiles the three C tools with `-static` using `musl-gcc` so they have zero dynamic library dependencies (`INTERP` and `NEEDED` are verified empty via `readelf`).
   - **`restarter` & `XPlatLauncher`**: Built with Cargo (`--offline`) across four targets:
     - `x86_64-unknown-linux-gnu` $\rightarrow$ `artifacts/linux-x64/`
     - `aarch64-unknown-linux-gnu` (using `aarch64-linux-gnu-gcc` as linker) $\rightarrow$ `artifacts/linux-arm/`
     - `x86_64-pc-windows-gnu` (using Ubuntu's `x86_64-w64-mingw32-gcc`) $\rightarrow$ `artifacts/windows-x64/`
     - `aarch64-pc-windows-gnullvm` (using `llvm-mingw`'s `aarch64-w64-mingw32-clang` with `+crt-static` so `libunwind` is linked statically) $\rightarrow$ `artifacts/windows-arm/`
   - **Verification**: Verifies ELF/PE architecture on every output binary via `file` (`verify_arch`) and checks `GLIBC` version requirements via `readelf -V`.

### Windows C/C++ Native Tools (`IntelliJ-win`)

The `IntelliJ-win` target runs on Windows buildbot machines (`adt-win-*`) via `native_win.cmd <out_dir> <dist_dir> <build_number>`, which invokes:
- `build-win-fsnotifier.cmd` (`tools/idea/native/WinFsNotifier`)
- `build-win-process-list-helper.cmd` (`tools/idea/native/WinProcessListHelper`)
- `build-win-shell-integration.cmd` (`tools/idea/native/WinShellIntegration`, using JNI headers from `prebuilts/studio/jdk/jni_headers/jdk11`)

Each script runs Visual Studio 2019's bundled CMake twice in separate build directories (`<Tool>-x64` with `-A x64` and `<Tool>-arm64` with `-A ARM64`) and copies the resulting `Release` binaries to `<dist_dir>\artifacts\windows-x64\` and `<dist_dir>\artifacts\windows-arm\`. (`WinElevator` is intentionally not built here; see note above.)

### macOS Universal Native Tools (`IntelliJ-mac_arm64`)

The `IntelliJ-mac_arm64` target runs on macOS build machines via `native_mac.sh <out_dir> <dist_dir> <build_number>`, which invokes `build-mac-{touchbar,envreader,screenmenu,fsnotifier,xplat-launcher,restarter}.sh` (sharing helpers from `build-mac-common.sh`):
- C/C++/Objective-C projects (`MacTouchBar`, `MacEnvReader`, `MacScreenMenu`, `fsNotifier/mac`) are built with `prebuilts/studio/sdk/darwin/cmake` configured for both `x86_64` and `arm64`.
- Rust projects (`XPlatLauncher`, `restarter`) are built with `prebuilts/rust-toolchain/darwin` for `x86_64-apple-darwin` and `aarch64-apple-darwin` and combined into universal Mach-O binaries using `lipo -create`.
- `verifyArchs` checks `lipo -archs` on each output binary before copying it to `<dist_dir>/artifacts/mac/`.

---

## 3. Local Builds

### Linux (via RBE — matches CI execution)

From the repository root (`/path/to/studio-intellij`):

```bash
rm -rf out dist
tools/idea/platform/build-scripts/native/linux_tools_re_proxy.sh out dist 111
```

> **Note**: `linux_tools_re_proxy.sh` executes inside the remote container specified by `container-image` in `android-studio.cfg`. If you modified `Dockerfile`, you must either test locally with Docker first (see below) or push the new Docker image and update `android-studio.cfg` before running `linux_tools_re_proxy.sh`.

### Linux (via Local Docker — for testing `Dockerfile` or `linux_tools.sh` changes)

1. Install Docker on gLinux (`go/installdocker`).
2. Either run the helper script from `tools/idea/platform/build-scripts/native/`:
   ```bash
   cd tools/idea/platform/build-scripts/native
   ./linux_tools_local_dev.sh
   ```
   Or build and test a modified `Dockerfile` locally before pushing to GCR:
   ```bash
   # Prepare Docker build context with Cargo lockfiles for prefetching
   work_dir=$(mktemp -d)
   cp tools/idea/platform/build-scripts/native/Dockerfile "$work_dir/"
   mkdir -p "$work_dir/cargo/XPlatLauncher" "$work_dir/cargo/restarter"
   cp tools/idea/native/XPlatLauncher/Cargo.{toml,lock} "$work_dir/cargo/XPlatLauncher/"
   cp tools/idea/native/restarter/Cargo.{toml,lock} "$work_dir/cargo/restarter/"

   docker build -t intellij_native:local "$work_dir"
   rm -rf "$work_dir"

   # Run linux_tools.sh inside the local image
   docker run --rm \
     -v "$(pwd):/workspace:ro" \
     intellij_native:local \
     bash -c "/workspace/tools/idea/platform/build-scripts/native/linux_tools.sh /tmp/out /tmp/dist 111 && ls -la /tmp/dist/artifacts/*/"
   ```

### macOS

On a macOS checkout:

```bash
tools/idea/platform/build-scripts/native/native_mac.sh out dist 111
```

### Windows

On a Windows checkout with Visual Studio 2019 BuildTools installed:

```cmd
tools\idea\platform\build-scripts\native\native_win.cmd out dist 111
```

---

## 4. Updating the RBE Docker Image

The RBE container image (`Dockerfile`) encapsulates:
- Ubuntu 20.04 base image (ensuring a `GLIBC_2.31` compatibility ceiling).
- Cross-compilers: `gcc-aarch64-linux-gnu` (Linux ARM64), `mingw-w64` (Windows x64), and `llvm-mingw` (Windows ARM64 for `aarch64-pc-windows-gnullvm`).
- Pre-downloaded `musl-1.2.6.tar.gz` and pre-fetched Cargo crates (`XPlatLauncher` and `restarter`) so the build can run completely offline on RBE workers (`--offline`).

When you modify `Dockerfile` or update `Cargo.lock` in `XPlatLauncher` / `restarter`:

1. **Build and push the image to GCR**:
   - Using Cloud Build (`build-docker.sh`):
     ```bash
     gcloud auth application-default login --project="google.com:android-studio-alphasource"
     tools/idea/platform/build-scripts/native/build-docker.sh
     ```
   - Or if `gcloud builds submit` is blocked by Context-Aware Access on Cloudtop, build locally and push directly using Application Default Credentials:
     ```bash
     gcloud auth application-default print-access-token | docker login -u oauth2accesstoken --password-stdin https://gcr.io
     docker tag intellij_native:local gcr.io/google.com/android-studio-alphasource/intellij_native:latest
     docker push gcr.io/google.com/android-studio-alphasource/intellij_native:latest
     ```
2. **Update `android-studio.cfg`**:
   Copy the new `@sha256:...` digest printed by the push into `container-image` in `tools/idea/platform/build-scripts/native/android-studio.cfg`.

---

## 5. Dropping Prebuilts into `platform/tools/idea`

Once a build finishes on `ab/git_studio-intellij` (or Rapid project `adt_drop.intellij_utils`), prebuilts are dropped into `platform/tools/idea` via `google3/wireless/android/devtools/studio/prebuilt_drop`:

```bash
# Drop Linux + cross-compiled Windows tools from an IntelliJ-linux build_id:
blaze run //wireless/android/devtools/studio/prebuilt_drop:prebuilt_drop -- \
  --config=LinuxFsNotifier,LinuxLauncher,LinuxRestarter,WinLauncher,WinRestarter,WslTools \
  --branch=studio-main \
  --build_id=<INTELLIJ_LINUX_BUILD_ID>

# Drop Windows MSVC tools from an IntelliJ-win build_id:
blaze run //wireless/android/devtools/studio/prebuilt_drop:prebuilt_drop -- \
  --config=WinFsNotifier,WinProcessListHelper,WinShellIntegration \
  --branch=studio-main \
  --build_id=<INTELLIJ_WIN_BUILD_ID>

# Drop macOS tools from an IntelliJ-mac_arm64 build_id:
blaze run //wireless/android/devtools/studio/prebuilt_drop:prebuilt_drop -- \
  --config=MacEnvReader,MacFsNotifier,MacLauncher,MacRestarter,MacScreenMenu,MacTouchBar \
  --branch=studio-main \
  --build_id=<INTELLIJ_MAC_BUILD_ID>
```
