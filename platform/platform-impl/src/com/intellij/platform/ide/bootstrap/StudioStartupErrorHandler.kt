package com.intellij.platform.ide.bootstrap

import com.intellij.ide.BrowserUtil
import java.nio.file.Path

class StudioStartupErrorHandler : StartupErrorHandler {
  override fun uploadLogs(error: Throwable, logs: Path?): String {
    val url = "https://issuetracker.google.com/issues/new?component=192708"

    // Automatically launch the default web browser to the bug ticket
    BrowserUtil.browse(url)

    return "N/A\nOpened bug tracker in your browser.\n" +
           "If it didn't open, please file this issue at: $url"
  }
}
