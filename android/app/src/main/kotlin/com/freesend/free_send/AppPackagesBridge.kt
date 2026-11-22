package com.freesend.free_send

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Lists installed apps whose APK can be sent to another device. */
class AppPackagesBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "list" -> {
                // PackageManager queries are expensive; run them off the
                // platform thread so Flutter frames keep rendering, then
                // hop back to deliver the result.
                Thread {
                    val apps = listApps()
                    Handler(Looper.getMainLooper()).post {
                        result.success(apps)
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    private fun listApps(): List<Map<String, String>> {
        val packageManager = context.packageManager
        return packageManager.getInstalledApplications(0)
            .asSequence()
            .filter { info: ApplicationInfo ->
                // Only apps the user installed (or updated over a system
                // image) are shareable - skip the OS packages before paying
                // for label lookups and disk stats.
                val userInstalled =
                    (info.flags and ApplicationInfo.FLAG_SYSTEM == 0) ||
                        (info.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP != 0)
                userInstalled &&
                    !info.sourceDir.isNullOrEmpty() &&
                    File(info.sourceDir).exists()
            }
            .flatMap { info: ApplicationInfo ->
                val label = packageManager.getApplicationLabel(info).toString()
                val version = ""
                val bundles = mutableListOf(
                    mapOf(
                        "name" to label,
                        "path" to info.sourceDir,
                        "version" to version,
                    ),
                )
                // Modern apps ship split APKs; send each one as a separate
                // bundle so an install on the other side has everything.
                info.splitSourceDirs?.forEachIndexed { index, path ->
                    if (File(path).exists()) {
                        bundles.add(
                            mapOf(
                                "name" to "$label (part ${index + 1})",
                                "path" to path,
                                "version" to version,
                            ),
                        )
                    }
                }
                bundles
            }
            .sortedBy { it["name"]?.lowercase() ?: "" }
            .toList()
    }

    companion object {
        private const val CHANNEL = "com.freesend.free_send/apps"
    }
}