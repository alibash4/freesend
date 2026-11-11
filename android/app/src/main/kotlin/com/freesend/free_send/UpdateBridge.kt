package com.freesend.free_send

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands a downloaded update to Android's package installer.
 *
 * The APK is shared through a FileProvider so the installer can read it
 * without the app holding broad storage permissions. After the intent is
 * fired the app exits, because a running process keeps its old code loaded.
 */
class UpdateBridge(
    private val context: android.content.Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installApk" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrEmpty()) {
                    result.error("argument", "An update file path is required.", null)
                    return
                }
                installApk(File(path), result)
            }
            "canInstall" -> result.success(canInstall())
            "openInstallSettings" -> {
                openInstallSettings()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun installApk(file: File, result: MethodChannel.Result) {
        if (!file.exists()) {
            result.error("missing", "The downloaded update no longer exists.", null)
            return
        }
        if (!canInstall()) {
            result.error(
                "permission",
                "Allow Free Send to install apps from its settings page, " +
                    "then try again.",
                null,
            )
            return
        }
        try {
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.updates",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("failed", error.message ?: "Could not open the installer.", null)
        }
    }

    /** Whether the user has granted "install unknown apps" to Free Send. */
    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || context.packageManager.canRequestPackageInstalls()

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${context.packageName}"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            // Some builds hide the page; the permission check will keep failing
            // and the user can reach it from system settings.
        }
    }

    companion object {
        private const val CHANNEL = "com.freesend.free_send/updates"
    }
}
