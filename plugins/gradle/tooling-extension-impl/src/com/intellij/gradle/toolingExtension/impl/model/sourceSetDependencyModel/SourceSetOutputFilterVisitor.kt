// Copyright 2000-2026 JetBrains s.r.o. and contributors. Use of this source code is governed by the Apache 2.0 license.
package com.intellij.gradle.toolingExtension.impl.model.sourceSetDependencyModel

import org.gradle.api.file.FileCollection
import org.gradle.api.file.FileSystemLocation
import java.io.File

/**
 * Decorates a [GradleSourceSetDependencyVisitor] to skip files or file collections
 * that are already part of the source set output directories.
 *
 * TODO: Workaround for IDEA-392454.
 */
internal class SourceSetOutputFilterVisitor(
  private val delegate: GradleSourceSetDependencyVisitor,
  private val sourceSetOutputFiles: Set<File>,
) : GradleSourceSetDependencyVisitor by delegate {

  override fun visitFileCollection(fileCollection: FileCollection) {
    if (sourceSetOutputFiles.isNotEmpty()) {
      val files = runCatching { fileCollection.files }.getOrNull()
      if (files != null && files.isNotEmpty() && sourceSetOutputFiles.containsAll(files)) {
        return
      }
    }
    delegate.visitFileCollection(fileCollection)
  }

  override fun visitFile(file: FileSystemLocation) {
    if (sourceSetOutputFiles.isNotEmpty()) {
      val f = runCatching { file.asFile }.getOrNull()
      if (f != null && f in sourceSetOutputFiles) {
        return
      }
    }
    delegate.visitFile(file)
  }
}
