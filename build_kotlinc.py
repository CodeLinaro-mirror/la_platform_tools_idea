#!/usr/bin/env python3
from pathlib import Path
import argparse
import os
import platform
import re
import shlex
import subprocess
import sys


# This script builds Kotlinc from platform/external/jetbrains/kotlin and updates the IntelliJ
# project files at .idea/libraries/kotlinc_* to point to the Kotlinc build output.
def main():
    parser = argparse.ArgumentParser(description='Build Kotlinc and update IntelliJ project model')
    parser.add_argument('--clean', action='store_true')
    args = parser.parse_args()

    # Find workspace root.
    script_dir = Path(__file__).parent
    workspace = script_dir.joinpath('../..').resolve(strict=True)
    assert workspace.joinpath('MODULE.bazel').exists(), 'failed to find workspace root'

    # Set properties not currently exposed as flags.
    args.intellij_dir = workspace.joinpath('tools/idea')
    args.kotlinc_dir = workspace.joinpath('external/jetbrains/kotlin')
    args.kotlinc_version = compute_bootstrap_version(args.intellij_dir)
    args.gradlew = args.kotlinc_dir.joinpath('gradlew')
    args.cmd_env = os.environ.copy()
    args.cmd_env['JAVA_HOME'] = str(compute_java_home(workspace, 'jbrjdk-next'))
    args.gradle_jdk_args = [
        # Unfortunately, the Kotlin compiler build requires several different JDKs.
        # We provide the JDKs from prebuilts to avoid network issues in CI (e.g. b/482057769).
        '-Dorg.gradle.java.installations.auto-download=false',
        '-Dorg.gradle.java.installations.auto-detect=false',
        '-Dorg.gradle.java.home=' + str(compute_java_home(workspace, 'jbrjdk-next')),
        '-Dorg.gradle.java.installations.paths=' + ','.join([
            str(compute_java_home(workspace, 'jbrjdk-next')),
            str(compute_java_home(workspace, 'jdk17')),
            str(compute_java_home(workspace, 'jdk11')),
            str(compute_java_home(workspace, 'jdk8')),
        ]),
    ]

    build_kotlin_compiler(args)
    update_ide_project_model(args)


# Builds Kotlinc (via Gradle).
def build_kotlin_compiler(args):
    clean_args = ['clean', '--no-build-cache'] if args.clean else []
    # This is similar to publishCompiler() in project-model-updater, we just tweak the options
    # (e.g. we set teamcity=true to get optimized production artifacts).
    cmd = [
        str(args.gradlew),
        f'--project-dir={args.kotlinc_dir}',
        '--no-daemon',
        *args.gradle_jdk_args,
        *clean_args,
        'publishIdeArtifacts',
        ':prepare:ide-plugin-dependencies:kotlin-dist-for-ide:publish',
        f'-Pkotlin.build.deploy-path={args.intellij_dir}/lib/kotlin-snapshot',  # From project-model-updater.
        '-Ppublish.ide.plugin.dependencies=true',
        f'-PdeployVersion={args.kotlinc_version}',
        f'-Pbuild.number={args.kotlinc_version}',
        '-Pteamcity=true',  # Makes this a release build rather than a dev build.
        '-Pkotlin.build.cache.local.enabled=true',  # Enables disk cache (shared across incremental CI builds).
    ]
    run_subprocess(cmd, args.cmd_env, 'Building the Kotlin compiler')


# Updates IntelliJ project files to point to the local Kotlinc build.
def update_ide_project_model(args):
    updater_dir: Path = args.intellij_dir.joinpath('plugins/kotlin/util/project-model-updater')
    clean_args = ['clean', '--no-build-cache'] if args.clean else []
    cmd = [
        str(args.gradlew),
        f'--project-dir={updater_dir}',
        '--no-daemon',
        *args.gradle_jdk_args,
        *clean_args,
        'run',
        '--args=kotlincArtifactsMode=BOOTSTRAP',
    ]
    run_subprocess(cmd, args.cmd_env, 'Running project-model-updater')


# Finds the Kotlin bootstrap version expected by project-model-updater (e.g., "2.4.255-dev-255").
def compute_bootstrap_version(intellij_dir: Path) -> str:
    src = intellij_dir.joinpath('plugins/kotlin/util/project-model-updater/src/org/jetbrains/tools/model/updater/kotlincLibraries.kt')
    match = re.search(r'BOOTSTRAP_VERSION\s*=\s*"([^"]+)"', src.read_text('utf-8'))
    if not match:
        sys.exit(f'ERROR: Failed to find BOOTSTRAP_VERSION in {src}')
    return match.group(1)


# Finds a standard JDK with which to run Gradle.
def compute_java_home(workspace: Path, version: str) -> Path:
    jdk_base = workspace.joinpath(f'prebuilts/studio/jdk/{version}')
    system = platform.system()
    if system == 'Linux':
        return jdk_base.joinpath('linux')
    elif system == 'Darwin':
        subdir = 'mac-arm64' if platform.machine() == 'arm64' and version != 'jdk8' else 'mac'
        return jdk_base.joinpath(subdir, 'Contents/Home')
    else:
        sys.exit(f'ERROR: Unrecognized system: {system}')


# A wrapper around subprocess.run() with additional logging and stricter env.
def run_subprocess(cmd, env, description):
    cmd_quoted = ' '.join([shlex.quote(arg) for arg in cmd])
    print(f'\n{description}:\n\n{cmd_quoted}\n')
    sys.stdout.flush()
    result = subprocess.run(cmd, env=env)
    if result.returncode != 0:
        sys.exit(f'\nERROR: {description} failed (see logs).\n')


if __name__ == '__main__':
    main()
