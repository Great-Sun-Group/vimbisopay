package com.vimbisopay.vimbisopay_app

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
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
import java.io.FileInputStream
import java.io.IOException

class ApkInstallerPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val TAG = "ApkInstallerPlugin"
    
    // Store the last APK file path for retry
    private var lastApkFilePath: String? = null

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
                        Log.d(TAG, "Preparing to install APK from path: $filePath")
                        // Store the file path for potential retry
                        lastApkFilePath = filePath
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
            "retryInstallation" -> {
                // Method to retry installation after user enables "Allow from this source"
                if (lastApkFilePath != null) {
                    try {
                        Log.d(TAG, "Retrying APK installation from path: $lastApkFilePath")
                        val success = installApk(lastApkFilePath!!)
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error retrying APK installation", e)
                        result.error("RETRY_ERROR", "Error retrying APK installation: ${e.message}", e.stackTraceToString())
                    }
                } else {
                    Log.e(TAG, "No previous APK file path stored for retry")
                    result.error("NO_FILE_PATH", "No previous APK file path stored for retry", null)
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
            
            // Use PackageInstaller API for installation with status updates
            val packageInstaller = context.packageManager.packageInstaller
            
            // Create a new session
            val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            val sessionId = packageInstaller.createSession(params)
            val session = packageInstaller.openSession(sessionId)
            
            Log.d(TAG, "PackageInstaller session created with ID: $sessionId")
            
            // Copy the APK file to the session
            FileInputStream(file).use { inputStream ->
                session.openWrite("package", 0, file.length()).use { outputStream ->
                    val buffer = ByteArray(65536)
                    var c: Int
                    while (inputStream.read(buffer).also { c = it } != -1) {
                        outputStream.write(buffer, 0, c)
                        outputStream.flush()
                    }
                }
            }
            
            Log.d(TAG, "APK file copied to PackageInstaller session")
            
            // Create a broadcast intent for installation status
            val intent = Intent(InstallationStatusReceiver.ACTION_INSTALLATION_STATUS)
            // Make the intent explicit by specifying the component
            intent.setClass(context, InstallationStatusReceiver::class.java)
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                sessionId,
                intent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )
            
            // Commit the session
            Log.d(TAG, "Committing PackageInstaller session")
            session.commit(pendingIntent.intentSender)
            Log.d(TAG, "PackageInstaller session committed, installation in progress")
            
            // The actual installation will happen asynchronously, and the status will be
            // broadcast to our InstallationStatusReceiver
            Log.d(TAG, "APK installation request sent to Android package installer - user must approve and restart app after installation")
            return true
        } catch (e: IOException) {
            Log.e(TAG, "IO error in installApk", e)
            throw e
        } catch (e: SecurityException) {
            Log.e(TAG, "Security error in installApk", e)
            throw e
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
