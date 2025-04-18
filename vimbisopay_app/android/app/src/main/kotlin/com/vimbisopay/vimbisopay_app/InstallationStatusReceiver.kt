package com.vimbisopay.vimbisopay_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * BroadcastReceiver to handle APK installation status updates.
 * 
 * This receiver is triggered when the PackageInstaller completes an installation
 * and provides feedback to the user via notifications.
 */
class InstallationStatusReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "InstallStatusReceiver"
        private const val CHANNEL_ID = "app_update_channel"
        private const val NOTIFICATION_ID = 1001
        
        // Action for the broadcast intent
        const val ACTION_INSTALLATION_STATUS = "com.vimbisopay.vimbisopay_app.INSTALLATION_STATUS"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received installation status broadcast: ${intent.action}")
        
        // Log all extras for debugging
        Log.d(TAG, "Intent extras:")
        intent.extras?.keySet()?.forEach { key ->
            Log.d(TAG, "  $key: ${intent.extras?.get(key)}")
        }
        
        if (intent.action == ACTION_INSTALLATION_STATUS) {
            val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -1)
            val packageName = intent.getStringExtra(PackageInstaller.EXTRA_PACKAGE_NAME)
            val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
            val otherPackageName = intent.getStringExtra(PackageInstaller.EXTRA_OTHER_PACKAGE_NAME)
            val storageStatus = intent.getIntExtra(PackageInstaller.EXTRA_STORAGE_PATH, -1)
            
            Log.d(TAG, "Installation status: $status, package: $packageName, message: $message")
            Log.d(TAG, "Other package: $otherPackageName, storage status: $storageStatus")
            
            // Map status code to a readable string for better logging
            val statusString = when (status) {
                PackageInstaller.STATUS_PENDING_USER_ACTION -> "STATUS_PENDING_USER_ACTION"
                PackageInstaller.STATUS_SUCCESS -> "STATUS_SUCCESS"
                PackageInstaller.STATUS_FAILURE -> "STATUS_FAILURE"
                PackageInstaller.STATUS_FAILURE_ABORTED -> "STATUS_FAILURE_ABORTED"
                PackageInstaller.STATUS_FAILURE_BLOCKED -> "STATUS_FAILURE_BLOCKED"
                PackageInstaller.STATUS_FAILURE_CONFLICT -> "STATUS_FAILURE_CONFLICT"
                PackageInstaller.STATUS_FAILURE_INCOMPATIBLE -> "STATUS_FAILURE_INCOMPATIBLE"
                PackageInstaller.STATUS_FAILURE_INVALID -> "STATUS_FAILURE_INVALID"
                PackageInstaller.STATUS_FAILURE_STORAGE -> "STATUS_FAILURE_STORAGE"
                else -> "UNKNOWN_STATUS($status)"
            }
            Log.d(TAG, "Status code: $statusString")
            
            when (status) {
                PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                    // This status means the user needs to take action to complete the installation
                    Log.d(TAG, "Installation requires user action")
                    
                    // Extract the confirmation intent
                    val confirmationIntent = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                    if (confirmationIntent != null) {
                        // Check if this is a CONFIRM_INSTALL action (likely the "Allow from this source" prompt)
                        val action = confirmationIntent.action
                        val isConfirmInstall = action == "android.content.pm.action.CONFIRM_INSTALL"
                        
                        Log.d(TAG, "Confirmation intent action: $action, isConfirmInstall: $isConfirmInstall")
                        
                        // Add flags to start the activity
                        confirmationIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        
                        try {
                            // Start the confirmation activity (either package installer or settings)
                            context.startActivity(confirmationIntent)
                            
                            // If this is the "Allow from this source" prompt, show a helpful notification
                            if (isConfirmInstall) {
                                // Create an intent to return to the app
                                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                                val pendingIntent = if (launchIntent != null) {
                                    PendingIntent.getActivity(
                                        context,
                                        0,
                                        launchIntent,
                                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                                    )
                                } else {
                                    null
                                }
                                
                                // Show a notification to guide the user
                                showNotification(
                                    context,
                                    "Installation In Progress",
                                    "If prompted to enable 'Allow from this source', please enable it and return to VimbisoPay.",
                                    pendingIntent
                                )
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to start confirmation activity", e)
                            showNotification(
                                context,
                                "Installation Error",
                                "Failed to launch installer. Please try again."
                            )
                        }
                    } else {
                        Log.e(TAG, "No confirmation intent provided")
                        showNotification(
                            context,
                            "Installation Error",
                            "Failed to launch installer. Please try again."
                        )
                    }
                }
                
                PackageInstaller.STATUS_SUCCESS -> {
                    // Installation was successful
                    Log.d(TAG, "Installation successful for package: $packageName")
                    
                    // Create an intent to launch the app
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    val pendingIntent = if (launchIntent != null) {
                        PendingIntent.getActivity(
                            context,
                            0,
                            launchIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                    } else {
                        null
                    }
                    
                    showNotification(
                        context,
                        "Update Complete",
                        "VimbisoPay has been updated successfully. Tap to open.",
                        pendingIntent
                    )
                }
                
                PackageInstaller.STATUS_FAILURE_ABORTED -> {
                    // This is likely either:
                    // 1. User explicitly cancelled the installation
                    // 2. User is being redirected to enable "Allow from this source" setting
                    Log.d(TAG, "Installation process interrupted with status: $status, message: $message")
                    
                    // DO NOT show any notification for this status
                    // This is to avoid showing a "Installation Cancelled" notification when the user
                    // is just enabling the "Allow from this source" setting
                    Log.d(TAG, "Suppressing notification for STATUS_FAILURE_ABORTED")
                    
                    // Instead, the user will use the "Retry Installation" button in the app
                    // to continue the installation process after enabling the setting
                }
                
                PackageInstaller.STATUS_FAILURE,
                PackageInstaller.STATUS_FAILURE_BLOCKED,
                PackageInstaller.STATUS_FAILURE_CONFLICT,
                PackageInstaller.STATUS_FAILURE_INCOMPATIBLE,
                PackageInstaller.STATUS_FAILURE_INVALID,
                PackageInstaller.STATUS_FAILURE_STORAGE -> {
                    // Installation failed for other reasons
                    Log.e(TAG, "Installation failed with status: $status, message: $message")
                    showNotification(
                        context,
                        "Installation Failed",
                        message ?: "Failed to install the update. Please try again."
                    )
                }
            }
        }
    }
    
    /**
     * Shows a notification to the user.
     */
    private fun showNotification(
        context: Context,
        title: String,
        message: String,
        pendingIntent: PendingIntent? = null
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // Create the notification channel (required for Android O and above)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Updates",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for app updates"
            }
            notificationManager.createNotificationChannel(channel)
        }
        
        // Build the notification
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info) // Using a system icon
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
        
        // Add the pending intent if provided
        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
        }
        
        // Show the notification
        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }
}
