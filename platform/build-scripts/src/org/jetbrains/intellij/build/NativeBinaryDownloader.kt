// Copyright 2000-2026 JetBrains s.r.o. and contributors. Use of this source code is governed by the Apache 2.0 license.
package org.jetbrains.intellij.build

import org.jetbrains.intellij.build.dependencies.BuildDependenciesConstants.INTELLIJ_DEPENDENCIES_URL
import org.jetbrains.intellij.build.dependencies.BuildDependenciesDownloader
import java.nio.file.Path
import java.nio.file.StandardOpenOption
import kotlin.io.path.exists
import kotlin.io.path.isDirectory
import kotlin.io.path.isRegularFile
import kotlin.io.path.writeText

object NativeBinaryDownloader {
  private const val GROUP_ID = "org.jetbrains.intellij.deps"
  private const val LAUNCHER_ID = "launcher"
  private const val RESTARTER_ID = "restarter"
  private const val PACKAGING = "tar.gz"
  private const val LICENSE_FILE_NAME = "xplat-launcher-third-party-licenses.html"

  // Android Studio (b/342419219): we build platform binaries from source instead of downloading them from JetBrains.
  private fun findFileForAndroidStudio(fileName: String, context: BuildContext, os: OsFamily, arch: JvmArchitecture): Path {
    val resourcesDir = context.paths.communityHomeDirRoot.communityRoot.resolve("platform/build-scripts/resources")
    val path = when (os) {
      OsFamily.LINUX -> resourcesDir.resolve("linux/${arch.dirName}/$fileName")
      OsFamily.MACOS -> resourcesDir.resolve("mac/$fileName")
      OsFamily.WINDOWS -> {
        val ext = if (fileName.contains('.')) "" else ".exe"
        resourcesDir.resolve("win/${arch.dirName}/$fileName$ext")
      }
    }
    check(path.exists()) { "Android Studio (b/342419219): expected prebuilt binary at: $path" }
    return path
  }

  /**
   * Attempts to locate a local debug build of cross-platform launcher when in the development mode
   * and [org.jetbrains.intellij.build.BuildOptions.useLocalLauncher] is set to `true`.
   *
   * Otherwise, downloads and unpacks the launcher tarball.
   *
   * Returns a tuple of paths `(executable, license, extra-file?)` for the given platform (e.g., a console executable for Windows).
   */
  suspend fun getLauncher(context: BuildContext, os: OsFamily, arch: JvmArchitecture): Triple<Path, Path, Path?> {
    return Triple(
      findFileForAndroidStudio("launcher", context, os, arch),
      findFileForAndroidStudio("launcher_licenses.html", context, os, arch),
      null, // Not yet shipping the Windows console launcher in Studio (b/536093713).
    )
    /* Android Studio (b/342419219): we build platform binaries from source instead of downloading them from JetBrains.
    if (context.options.isInDevelopmentMode && context.options.useLocalLauncher) {
      val localLauncher = findLocalLauncher(context, os)
      if (localLauncher != null) return localLauncher
    }

    val (archiveFile, unpackedDir) = downloadAndUnpack(context, "launcherBuild", LAUNCHER_ID)
    val executableFile = findFile(archiveFile, unpackedDir, binName(os, arch, "xplat-launcher"))
    val licenseFile = findFile(archiveFile, unpackedDir, "license/${LICENSE_FILE_NAME}")
    val extraFile = when (os) {
      OsFamily.WINDOWS -> unpackedDir.resolve(binName(os, arch, "xplat-launcher-win-con"))
      else -> null
    }?.takeIf { it.isRegularFile() }
    return Triple(executableFile, licenseFile, extraFile)
    */
  }

  private fun findLocalLauncher(context: BuildContext, os: OsFamily): Triple<Path, Path, Path?>? {
    val targetDir = context.paths.communityHomeDirRoot.communityRoot.resolve("native/XPlatLauncher/target/debug")
    if (targetDir.isDirectory()) {
      val executableFile = targetDir.resolve(os.binaryName("xplat-launcher"))
      if (executableFile.isRegularFile()) {
        val licenseFile = targetDir.resolve(LICENSE_FILE_NAME)
        if (!licenseFile.exists()) {
          licenseFile.writeText("(cross-platform launcher license file stub)", options = arrayOf(StandardOpenOption.CREATE_NEW))
        }
        val extraFile = targetDir.resolve(os.binaryName("xplat-launcher-win-con")).takeIf { it.isRegularFile() }
        return Triple(executableFile, licenseFile, extraFile)
      }
    }

    return null
  }

  /**
   * Downloads and unpacks the restart helper tarball and returns a path to an executable for the given platform.
   */
  suspend fun getRestarter(context: BuildContext, os: OsFamily, arch: JvmArchitecture): Path {
    return findFileForAndroidStudio("restarter", context, os, arch)
    /* Android Studio (b/342419219): we build platform binaries from source instead of downloading them from JetBrains.
    val (archiveFile, unpackedDir) = downloadAndUnpack(context, "restarterBuild", RESTARTER_ID)
    return findFile(archiveFile, unpackedDir, binName(os, arch, "restarter"))
    */
  }

  private suspend fun downloadAndUnpack(context: BuildContext, propertyName: String, artifactId: String): Pair<Path, Path> {
    error("Android Studio (b/342419219): platform binaries should be built from source instead of downloaded from JetBrains")
    val communityRoot = context.paths.communityHomeDirRoot
    val version = context.dependenciesProperties.property(propertyName)
    val uri = BuildDependenciesDownloader.getUriForMavenArtifact(INTELLIJ_DEPENDENCIES_URL, GROUP_ID, artifactId, version, PACKAGING)
    val archiveFile = downloadFileToCacheLocation(uri.toString(), communityRoot)
    val unpackedDir = BuildDependenciesDownloader.extractFileToCacheLocation(communityRoot, archiveFile)
    return archiveFile to unpackedDir
  }

  private fun binName(os: OsFamily, arch: JvmArchitecture, baseName: String): String = "${os.osName}-${arch.archName}/${os.binaryName(baseName)}"

  @Suppress("SameParameterValue")
  private fun libName(os: OsFamily, arch: JvmArchitecture, baseName: String): String = "${os.osName}-${arch.archName}/${os.libraryName(baseName)}"

  private fun findFile(archiveFile: Path, unpackedDir: Path, relativePath: String): Path {
    val file = unpackedDir.resolve(relativePath)
    check(file.isRegularFile()) { "Executable '${relativePath}' not found in '${archiveFile.fileName}'" }
    return file
  }
}
