package com.aalumai.aalumai

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart <-> native bridge for Jarvis's device-level tools: battery status,
 * launching installed apps, and opening system settings pages.
 *
 * Every method either returns a real platform value or an error/false the
 * assistant can relay honestly — never a fabricated success. Dart-side
 * contract lives in `lib/features/jarvis/data/device_bridge.dart`.
 */
class JarvisActionsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "aalumai/jarvis_actions"
    }

    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val appContext = context
        if (appContext == null) {
            result.error("detached", "Jarvis actions plugin is not attached", null)
            return
        }
        when (call.method) {
            "batteryStatus" -> {
                val status = appContext.registerReceiver(
                    null,
                    IntentFilter(Intent.ACTION_BATTERY_CHANGED),
                )
                val level = status?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale = status?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
                val percent = if (scale > 0 && level >= 0) (level * 100) / scale else -1
                if (percent < 0) {
                    result.error("unavailable", "Battery level is unavailable", null)
                    return
                }
                val statusExtra =
                    status?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                val charging = statusExtra == BatteryManager.BATTERY_STATUS_CHARGING ||
                    statusExtra == BatteryManager.BATTERY_STATUS_FULL
                result.success(mapOf("level" to percent, "charging" to charging))
            }

            "openApp" -> {
                val packageName = call.argument<String>("package")
                if (packageName.isNullOrBlank()) {
                    result.error("bad_args", "openApp requires package", null)
                    return
                }
                val launch = appContext.packageManager.getLaunchIntentForPackage(packageName)
                if (launch == null) {
                    result.success(false)
                    return
                }
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    appContext.startActivity(launch)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }

            "openSettings" -> {
                val page = call.argument<String>("page")
                val intent = settingsIntent(page, appContext.packageName)
                if (intent == null) {
                    result.success(false)
                    return
                }
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    appContext.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun settingsIntent(page: String?, appPackage: String): Intent? = when (page) {
        "wifi" -> Intent(Settings.ACTION_WIFI_SETTINGS)
        "bluetooth" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
        "sound" -> Intent(Settings.ACTION_SOUND_SETTINGS)
        "display" -> Intent(Settings.ACTION_DISPLAY_SETTINGS)
        "battery" -> Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
        "apps" -> Intent(Settings.ACTION_APPLICATION_SETTINGS)
        "storage" -> Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS)
        "notifications" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, appPackage)
        }
        "location" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
        "security" -> Intent(Settings.ACTION_SECURITY_SETTINGS)
        else -> null
    }
}
