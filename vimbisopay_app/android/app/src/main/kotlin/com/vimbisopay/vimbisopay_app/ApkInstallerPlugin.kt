package com.vimbisopay.vimbisopay_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

class ApkInstallerPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val TAG = "ApkInstallerPlugin"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.vimbisopay.vimbisopay_app/apk_installer")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        Log.d(TAG, "ApkInstallerPlugin attached to engine")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "installApk" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    try {
                        Log.d(TAG, "Installing APK from path: $filePath")
                        val success = installApk(filePath)
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error installing APK", e)
                        result.error("INSTALL_ERROR", "Error installing APK: ${e.message}", e.stackTraceToString())
                    }
                } else {
                    Log.e(TAG, "File path is null")
                    result.error("INVALID_ARGUMENT", "File path is required", null)
                }
            }
            else -> {
                Log.w(TAG, "Method not implemented: ${call.method}")
                result.notImplemented()
            }
        }
    }

    private fun installApk(filePath: String): Boolean {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                Log.e(TAG, "APK file does not exist: $filePath")
                return false
            }

            Log.d(TAG, "APK file exists, size: ${file.length()} bytes")
            
            // Create content URI using FileProvider
            val contentUri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file
            )
            
            Log.d(TAG, "Content URI created: $contentUri")

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(contentUri, "application/vnd.android.package-archive")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            Log.d(TAG, "Starting installation intent")
            context.startActivity(intent)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error in installApk", e)
            throw e
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        Log.d(TAG, "ApkInstallerPlugin detached from engine")
    }
}
