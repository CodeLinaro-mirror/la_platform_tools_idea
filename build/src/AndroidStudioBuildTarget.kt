import org.jetbrains.intellij.build.AndroidStudioProperties
import org.jetbrains.intellij.build.BuildContext
import org.jetbrains.intellij.build.BuildLifetime
import org.jetbrains.intellij.build.BuildPaths
import org.jetbrains.intellij.build.createBuildTasks
import org.jetbrains.intellij.build.impl.BuildContextImpl

object AndroidStudioBuildTarget {
  @JvmStatic
  fun main(args: Array<String>) {
    BuildLifetime().use { lifetime ->
      val home = BuildPaths.COMMUNITY_ROOT
      val properties = AndroidStudioProperties()
      val buildContext = BuildContextImpl.createContext(home.communityRoot, properties, lifetime = lifetime)
      validateProductVersion(buildContext)
      val tasks = createBuildTasks(buildContext)
      tasks.buildDistributions()
    }
  }

  /**
   * Checks that the product version in AndroidStudioApplicationInfo.xml is consistent with the build number in build.txt
   * For example, product version  "2025.1.X.X" is consistent with build number "251.XXX" because 251 is shorthand for 2025.1.
   */
  private fun validateProductVersion(buildContext: BuildContext) {
    val appInfo = buildContext.applicationInfo
    val buildNum = buildContext.buildNumber
    check(buildNum.substringBefore('.') == "${appInfo.majorVersion.drop(2)}${appInfo.minorVersion}") {
      "The version specified in AndroidStudioApplicationInfo.xml is inconsistent with the build number in build.txt"
    }
  }
}
