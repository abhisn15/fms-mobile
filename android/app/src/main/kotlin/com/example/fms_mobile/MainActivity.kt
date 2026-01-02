package com.atenim

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val DEVELOPER_OPTIONS_CHANNEL = "com.atenim.fms/developer_options"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVELOPER_OPTIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeveloperOptionsEnabled" -> {
                    try {
                        val isEnabled = isDeveloperOptionsEnabled()
                        result.success(isEnabled)
                    } catch (e: Exception) {
                        result.error("DEVELOPER_OPTIONS_ERROR", "Failed to check developer options", e.message)
                    }
                }
                "openDeveloperOptions" -> {
                    try {
                        openDeveloperOptions()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("DEVELOPER_OPTIONS_ERROR", "Failed to open developer options", e.message)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Channel untuk location tracking
            val trackingChannel = NotificationChannel(
                "atenim_tracking",
                "Atenim Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Pelacakan lokasi absensi karyawan"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }

            // Channel untuk background service
            val serviceChannel = NotificationChannel(
                "atenim_service",
                "Atenim Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Layanan latar belakang Atenim"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }

            notificationManager.createNotificationChannel(trackingChannel)
            notificationManager.createNotificationChannel(serviceChannel)
        }
    }

    private fun isDeveloperOptionsEnabled(): Boolean {
        return try {
            // Check if developer options is enabled by checking the global setting
            val adbEnabled = Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0)
            val developmentSettingsEnabled = Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0)

            // Developer options is enabled if either ADB is enabled or development settings are enabled
            (adbEnabled == 1 || developmentSettingsEnabled == 1)
        } catch (e: Exception) {
            // If we can't check, assume it's not enabled for security
            false
        }
    }

    private fun openDeveloperOptions() {
        try {
            // Try to open developer options directly
            val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback: open general settings
            try {
                val intent = Intent(Settings.ACTION_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
            } catch (e2: Exception) {
                // If both fail, throw the original exception
                throw e
            }
        }
    }
}
