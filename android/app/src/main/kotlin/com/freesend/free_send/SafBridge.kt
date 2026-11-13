package com.freesend.free_send

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * Reads a folder the user granted through Android's Storage Access Framework.
 *
 * Dart cannot open a content:// tree directly, so the selected files are copied
 * into the app cache and the resulting path is handed back. The copy is a one
 * time cost before the transfer; no broad storage permission is requested.
 */
class SafBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "copyTree" -> {
                val uri = call.argument<String>("uri")
                if (uri.isNullOrEmpty()) {
                    result.error("argument", "A folder URI is required.", null)
                    return
                }
                copyTree(Uri.parse(uri), result)
            }
            else -> result.notImplemented()
        }
    }

    private fun copyTree(uri: Uri, result: MethodChannel.Result) {
        val tree = DocumentFile.fromTreeUri(context, uri)
        if (tree == null || !tree.canRead()) {
            result.error(
                "unreadable",
                "That Android folder is no longer readable. Choose it again.",
                null,
            )
            return
        }

        val rootName = tree.name?.ifBlank { null } ?: "folder"
        val baseDir = java.io.File(context.cacheDir, "freesend-saf")
        val target = java.io.File(baseDir, safeName(rootName))
        if (target.exists()) target.deleteRecursively()
        if (!target.mkdirs() && !target.isDirectory) {
            result.error("failed", "Could not create a cache folder.", null)
            return
        }

        try {
            val count = copyChildren(tree, target)
            result.success(mapOf("path" to target.absolutePath, "count" to count))
        } catch (error: Exception) {
            result.error(
                "failed",
                error.message ?: "Could not read that folder.",
                null,
            )
        }
    }

    private fun copyChildren(tree: DocumentFile, target: File): Int {
        var count = 0
        for (child in tree.listFiles()) {
            if (!child.canRead()) continue
            val childName = safeName(child.name ?: "file")
            if (child.isDirectory) {
                val dir = File(target, uniqueName(target, childName))
                if (dir.mkdirs() || dir.isDirectory) {
                    count += copyChildren(child, dir)
                }
            } else {
                val file = uniqueFile(target, childName)
                context.contentResolver.openInputStream(child.uri)?.use { input ->
                    FileOutputStream(file).use { output ->
                        input.copyTo(output)
                    }
                } ?: continue
                count++
            }
        }
        return count
    }

    private fun uniqueName(parent: File, name: String): String {
        var candidate = name
        var suffix = 1
        while (File(parent, candidate).exists()) {
            candidate = "$name ($suffix)"
            suffix++
        }
        return candidate
    }

    private fun uniqueFile(parent: File, name: String): File {
        val file = File(parent, name)
        if (!file.exists()) return file
        val dot = name.lastIndexOf('.')
        val base = if (dot > 0) name.substring(0, dot) else name
        val extension = if (dot > 0) name.substring(dot) else ""
        var suffix = 1
        while (true) {
            val candidate = File(parent, "$base ($suffix)$extension")
            if (!candidate.exists()) return candidate
            suffix++
        }
    }

    private fun safeName(value: String): String =
        value.replace(Regex("[\\\\/:*?\"<>|]"), "_").take(120)

    companion object {
        private const val CHANNEL = "com.freesend.free_send/saf"
    }
}