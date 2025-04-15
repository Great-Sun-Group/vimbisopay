package com.vimbisopay.vimbisopay_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import android.util.Log

class MainActivity: FlutterFragmentActivity() {
    private val TAG = "MainActivity"

    override fun getRenderMode(): RenderMode {
        return RenderMode.surface
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // Register the ApkInstallerPlugin
        try {
            Log.d(TAG, "Registering ApkInstallerPlugin")
            flutterEngine.plugins.add(ApkInstallerPlugin())
            Log.d(TAG, "ApkInstallerPlugin registered successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error registering ApkInstallerPlugin", e)
        }
    }
}
