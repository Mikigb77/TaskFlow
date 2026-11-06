package com.example.agenda

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Installs a newer staging build that Dart has downloaded and checked
 * (lib/services/app_update.dart). Only the private staging package can: it is
 * the only build with REQUEST_INSTALL_PACKAGES (src/staging/AndroidManifest.xml).
 * The production app updates through Google Play.
 *
 * On Android 12 and newer an app updating itself needs no confirmation, so
 * Android replaces the app at once and closes it; older versions show their
 * own confirmation first.
 */
class AppUpdateBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "taskflow/app-update")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "install" -> install(call.argument<String>("path"), result)
                // Builds download by themselves only off mobile data.
                "metered" -> result.success(
                    (activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager)
                        .isActiveNetworkMetered
                )
                else -> result.notImplemented()
            }
        }
        listener = { status -> channel.invokeMethod("installResult", status) }
    }

    private fun install(path: String?, result: MethodChannel.Result) {
        if (!BuildConfig.TASKFLOW_INTERNAL_STAGING || activity.packageName != "com.example.agenda.staging") {
            return result.error("disabled", "Only the staging build updates itself.", null)
        }
        val file = path?.let(::File)
        if (file == null || !file.isFile) return result.error("missing", "The update file is gone.", null)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !activity.packageManager.canRequestPackageInstalls()) {
            // Android asks once whether TaskFlow Staging may install updates.
            return try {
                activity.startActivity(
                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}"))
                )
                result.success("permission")
            } catch (error: Exception) {
                result.error("failed", error.message, null)
            }
        }
        val context = activity.applicationContext
        Thread {
            try {
                val installer = context.packageManager.packageInstaller
                val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
                    setAppPackageName(context.packageName)
                    setSize(file.length())
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
                    }
                }
                val id = installer.createSession(params)
                installer.openSession(id).use { session ->
                    file.inputStream().use { input ->
                        session.openWrite("taskflow-staging.apk", 0, file.length()).use { output ->
                            input.copyTo(output)
                            session.fsync(output)
                        }
                    }
                    val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                        (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
                    val status = PendingIntent.getBroadcast(
                        context, id, Intent(context, AppUpdateReceiver::class.java), flags
                    )
                    session.commit(status.intentSender)
                }
                activity.runOnUiThread { result.success("started") }
            } catch (error: Exception) {
                activity.runOnUiThread { result.error("failed", error.message, null) }
            }
        }.start()
    }

    fun close() {
        listener = null
        channel.setMethodCallHandler(null)
    }

    companion object {
        /** Tells Dart how an install that didn't replace the app ended. */
        @Volatile
        var listener: ((String) -> Unit)? = null
    }
}

/** The installer's answer to a commit (AppUpdateBridge). */
class AppUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                try {
                    context.startActivity(confirm!!.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                } catch (_: Exception) {
                    AppUpdateBridge.listener?.invoke("failed")
                }
            }
            // Android has replaced the app, and closed this one.
            PackageInstaller.STATUS_SUCCESS -> Unit
            PackageInstaller.STATUS_FAILURE_ABORTED -> AppUpdateBridge.listener?.invoke("cancelled")
            else -> AppUpdateBridge.listener?.invoke("failed")
        }
    }
}
