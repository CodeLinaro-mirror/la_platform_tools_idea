/***
 * Copyright 2024 Google LLC
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 ***/

package org.jetbrains.intellij.build

import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption
import kotlinx.collections.immutable.persistentListOf
import kotlinx.collections.immutable.toPersistentList
import com.intellij.platform.ijent.community.buildConstants.IJENT_BOOT_CLASSPATH_MODULE
import org.jetbrains.intellij.build.CommunityRepositoryModules.COMMUNITY_REPOSITORY_PLUGINS
import org.jetbrains.intellij.build.impl.PatchOverwriteMode
import org.jetbrains.intellij.build.impl.PlatformJarNames
import org.jetbrains.intellij.build.impl.PlatformJarNames.PLATFORM_CORE_NIO_FS
import org.jetbrains.intellij.build.impl.getPluginLayoutsByJpsModuleNames
import org.jetbrains.intellij.build.productLayout.ProductModulesContentSpec
import org.jetbrains.intellij.build.productLayout.productModules
import org.jetbrains.intellij.build.productLayout.CommunityModuleSets
import org.jetbrains.intellij.build.productLayout.CommunityProductFragments

/**
 * Configures the Sherlock distribution by specifying bundled plugins, JVM args, extra files, and more.
 * See also: BaseIdeaProperties, IdeaCommunityProperties.
 */
class ApaProperties(private val home: Path) : ProductProperties() {
  init {
    platformPrefix = "AndroidPerformanceAnalyzer"
    applicationInfoModule = "com.google.apa.branding"
    useSplash = false
    buildSourcesArchive = true
    productLayout.buildAllCompatiblePlugins = false
    productLayout.prepareCustomPluginRepositoryForPublishedPlugins = false
    productLayout.skipUnresolvedContentModules = true

    // Map native libraries so JarPackager extracts binaries to lib/<name>/ instead of bundling into JARs
    presignedNativeLibs = mapOf(
      "pty4j" to "pty4j",
      "jna" to "jna",
      "native" to "native", // sqlite-native
      "async-profiler" to "async-profiler",
      "skiko-awt-runtime-all" to "skiko-awt-runtime-all",
    )

    productLayout.productImplementationModules = listOf(
      "intellij.platform.starter"
    )
    productLayout.bundledPluginModules = persistentListOf(
      "intellij.performanceTesting",
      // Required by intellij.performanceTesting plugin dependencies:
      "intellij.platform.structureView.plugin",
      // Unbundled upstream in 2026.2; required by APA for lucene, opencsv, xstream, jettison, and commons-text dependencies:
      "intellij.libraries.misc.plugin"
    )

    // Unlike Android Studio and standard IntelliJ properties, ApaProperties does not call
    // configurePropertiesForAllEditionsOfIntelliJIdea. Therefore, we must manually configure
    // essential platform modules (such as intellij.java.rt) and our custom branding here.
    productLayout.addPlatformSpec { layout, _ ->
      layout.withModule("com.google.apa.branding", "resources.jar")
      layout.withModule("intellij.java.rt", "idea_rt.jar")
      layout.withModule(IJENT_BOOT_CLASSPATH_MODULE, PLATFORM_CORE_NIO_FS)

      // Force packaging of test framework modules in the SDK (workaround for 2026.1 platform removal):
      for (moduleName in listOf(
        "intellij.platform.testFramework",
        "intellij.platform.testFramework.common",
        "intellij.java.testFramework",
        "intellij.java.testFramework.shared",
        "intellij.platform.testFramework.core",
        "intellij.platform.testFramework.teamCity",
      )) {
        layout.withModule(moduleName, PlatformJarNames.TEST_FRAMEWORK_JAR)
      }
      layout.withModule("intellij.platform.jewel.intUi.standalone", PlatformJarNames.TEST_FRAMEWORK_JAR)
      layout.withModule("intellij.platform.jewel.markdown.intUiStandaloneStyling", PlatformJarNames.TEST_FRAMEWORK_JAR)
    }

    // Fill in the remaining plugin layouts (including "performanceTesting" plugins)
    // so we can correctly patch all plugin layouts below.
    productLayout.pluginLayouts = getPluginLayoutsByJpsModuleNames(productLayout.bundledPluginModules, productLayout).toPersistentList()

    // Patch plugin.xml files to ensure plugins are non-updatable. We want platform
    // plugins to always come from our own IntelliJ fork (which may have patches, for example).
    // Note: this logic is validated by an assertion in check_plugin.py in our Bazel build.
    for (pluginLayout in productLayout.pluginLayouts) {
      val delegatePatcher = pluginLayout.pluginXmlPatcher
      pluginLayout.pluginXmlPatcher = { pluginXml, ctx ->
        delegatePatcher(pluginXml, ctx).replace("allow-bundled-update=\"true\"", "allow-bundled-update=\"false\"")
      }
    }
  }

  override suspend fun copyAdditionalFiles(targetDir: Path, context: BuildContext) {
    super.copyAdditionalFiles(targetDir, context)
    Files.copy(home.resolve("LICENSE.txt"), targetDir.resolve("LICENSE.txt"), StandardCopyOption.REPLACE_EXISTING)
    Files.copy(home.resolve("NOTICE.txt"), targetDir.resolve("NOTICE.txt"), StandardCopyOption.REPLACE_EXISTING)
  }

  override val baseFileName: String = "apa"

  override fun getBaseArtifactName(appInfo: ApplicationInfoProperties, buildNumber: String): String = "apa-platform"

  override fun getSystemSelector(appInfo: ApplicationInfoProperties, buildNumber: String): String = "AndroidPerformanceAnalyzer"

  override fun getProductContentDescriptor(): ProductModulesContentSpec = productModules {
    alias("com.intellij.modules.java-capable")

    include(CommunityProductFragments.javaIdeBaseFragment())
    moduleSet(CommunityModuleSets.ideCommon())
  }

  override fun createLinuxCustomizer(projectHome: Path): LinuxDistributionCustomizer {
    return object : LinuxDistributionCustomizer() {
      init {
        buildArtifactWithoutRuntime = true
      }

      override suspend fun copyAdditionalFiles(targetDir: Path, arch: JvmArchitecture, context: BuildContext) {
        // profiler.sh is added to resources/linux/scripts for Android Studio GameTools and unconditionally
        // copied by LinuxDistributionBuilder; delete it here since APA does not use GameTools.
        Files.deleteIfExists(targetDir.resolve("bin/profiler.sh"))
      }
    }
  }

  override fun createMacCustomizer(projectHome: Path): MacDistributionCustomizer {
    return object : MacDistributionCustomizer() {
      init {
        bundleIdentifier = "com.google.android.performance.analyzer"
        icnsPath = projectHome.resolve("apa-branding/resources/artwork/apa_mac.icns")
      }
    }
  }

  override fun createWindowsCustomizer(projectHome: Path): WindowsDistributionCustomizer {
    return object : WindowsDistributionCustomizer() {
      init {
        icoPath = projectHome.resolve("apa-branding/resources/artwork/apa_win.ico")
        buildZipArchiveWithBundledJre = false
        buildZipArchiveWithoutBundledJre = true
      }
    }
  }
}
