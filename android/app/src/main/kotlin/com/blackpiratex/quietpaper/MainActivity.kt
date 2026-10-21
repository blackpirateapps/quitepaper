package com.blackpiratex.quietpaper

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import com.blackpiratex.quietpaper.widget.QuickCaptureWidgetProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL_UPDATER = "com.blackpiratex.quietpaper/updater"
    private val CHANNEL_QUICK_CAPTURE = "com.blackpiratex.quietpaper/quick_capture"

    private var initialCaptureData: Map<String, Any?>? = null
    private var quickCaptureChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleCaptureIntent(intent, isInitial = true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCaptureIntent(intent, isInitial = false)
    }

    private fun handleCaptureIntent(intent: Intent?, isInitial: Boolean) {
        if (intent == null) return
        val isWidgetCapture = intent.action == QuickCaptureWidgetProvider.ACTION_QUICK_CAPTURE ||
                intent.getStringExtra("origin") == "widget"

        if (isWidgetCapture) {
            val data = mapOf(
                "origin" to "widget"
            )
            if (isInitial) {
                initialCaptureData = data
            } else {
                quickCaptureChannel?.invokeMethod("onQuickCaptureRequested", data)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_UPDATER).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceAbis" -> {
                    val abis = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        Build.SUPPORTED_ABIS.toList()
                    } else {
                        listOfNotNull(Build.CPU_ABI, Build.CPU_ABI2)
                    }
                    result.success(abis)
                }
                "canRequestPackageInstalls" -> {
                    val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(canInstall)
                }
                "openInstallPermissionSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "File path is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val apkFile = File(filePath)
                        if (!apkFile.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                            return@setMethodCallHandler
                        }

                        val authority = "${applicationContext.packageName}.fileprovider"
                        val contentUri = FileProvider.getUriForFile(this, authority, apkFile)

                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(contentUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(installIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.localizedMessage, null)
                    }
                }
                "openFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "File path is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val targetFile = File(filePath)
                        if (!targetFile.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist at $filePath", null)
                            return@setMethodCallHandler
                        }

                        val authority = "${applicationContext.packageName}.fileprovider"
                        val contentUri = FileProvider.getUriForFile(this, authority, targetFile)

                        val openIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(contentUri, mimeType)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        val chooser = Intent.createChooser(openIntent, "Open with").apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        quickCaptureChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_QUICK_CAPTURE).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialCaptureRequest" -> {
                        val data = initialCaptureData
                        initialCaptureData = null
                        result.success(data)
                    }
                    "moveTaskToBack" -> {
                        val moved = moveTaskToBack(true)
                        result.success(moved)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
