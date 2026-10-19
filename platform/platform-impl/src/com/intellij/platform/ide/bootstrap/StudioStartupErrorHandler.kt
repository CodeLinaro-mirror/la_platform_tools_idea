package com.intellij.platform.ide.bootstrap

import com.intellij.ide.BrowserUtil
import java.nio.file.Path

class StudioStartupErrorHandler : StartupErrorHandler {
  override fun uploadLogs(error: Throwable, logs: Path?): String {
    val isCannotActivate = isCannotActivateException(error)
    val url = if (isCannotActivate) {
      "https://issuetracker.google.com/issues/442392353"
    } else {
      "https://issuetracker.google.com/issues/new?component=192708"
    }

    // Automatically launch the default web browser to the bug ticket
    BrowserUtil.browse(url)

    return if (isCannotActivate) {
      "N/A\nOpened known issue b/442392353 in your browser.\n" +
      "Please vote +1 on the issue if the issue persists.\n" +
      "If it didn't open, please visit: $url"
    } else {
      "N/A\nOpened bug tracker in your browser.\n" +
      "If it didn't open, please file this issue at: $url"
    }
  }

  private fun isCannotActivateException(error: Throwable): Boolean {
    var current: Throwable? = error
    var depth = 0
    while (current != null && depth++ < 1000) {
      if (current.javaClass.name == "com.intellij.platform.ide.bootstrap.DirectoryLock\$CannotActivateException") {
        return true
      }
      current = current.cause
    }
    return false
  }
}
