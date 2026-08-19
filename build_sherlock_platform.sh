#!/usr/bin/env bash
set -eu

PROG_DIR="$(cd "$(dirname "$0")" && pwd)"

OUT="${PROG_DIR}/out/apa-platform"
DIST="${DIST_DIR:-"${OUT}/dist"}"

readonly AS_BUILD_NUMBER="$(sed 's/\.SNAPSHOT$//' "${PROG_DIR}/build.txt")"

BUILD_PROPERTIES=(
  "-Dintellij.build.output.root=${OUT}"
  "-Dbuild.number=${AS_BUILD_NUMBER}"
  "-Dintellij.build.dev.mode=false"
  "-Dcompile.parallel=true"
  "-Dintellij.build.dmg.with.bundled.jre=false"
  "-Dintellij.build.dmg.without.bundled.jre=true"
  "-Dintellij.build.skip.build.steps=repair_utility_bundle_step,mac_dmg,mac_sign,mac_sit,windows_exe_installer,linux aarch64,windows aarch64,search_index"
  "-Dintellij.build.incremental.compilation=true"
  "-Dintellij.build.incremental.compilation.fallback.rebuild=false"
  "-Dintellij.build.store.git.revision=false"
)

"${PROG_DIR}/platform/jps-bootstrap/jps-bootstrap.sh" "${BUILD_PROPERTIES[@]}" "${PROG_DIR}" intellij.idea.community.build ApaPlatformBuildTarget
# --- Android Build Artifact Copy ---
# If DIST_DIR is set (by the Android Build system), copy the contents of OUT
# to the designated artifact directory for Android Build to persist.
echo "Copying artifacts to ${DIST}"
mkdir -p "$DIST"
cp -Rfv "$OUT"/artifacts/apa-platform* "$DIST"
