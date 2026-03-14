package com.example.kwan_time

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        // WHY(VECTOR 3, VECTOR 6): Dart cannot reliably open OEM-specific settings
        // screens, so this bridge is used for exact-alarm and battery flows.
        const val DIAGNOSTICS_CHANNEL = "kwan_time/notification_diagnostics"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DIAGNOSTICS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSamsungDevice" -> result.success(isSamsungDevice())
                "isIgnoringBatteryOptimizations" -> result.success(
                    isIgnoringBatteryOptimizations(),
                )
                "openBatteryOptimizationSettings" -> result.success(
                    openBatteryOptimizationSettings(),
                )
                "openExactAlarmSettings" -> result.success(openExactAlarmSettings())
                "openSamsungBatterySettings" -> result.success(openSamsungBatterySettings())
                else -> result.notImplemented()
            }
        }
    }

    private fun isSamsungDevice(): Boolean =
        Build.MANUFACTURER.equals("samsung", ignoreCase = true)

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        return powerManager?.isIgnoringBatteryOptimizations(packageName) ?: true
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        val directIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }
        if (launchIntentIfPossible(directIntent)) {
            return true
        }

        val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        return launchIntentIfPossible(fallbackIntent)
    }

    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }

        // WHY(VECTOR 3): Android 12+ exact alarms are app-op gated and may fail
        // silently if users do not explicitly grant access.
        val exactAlarmIntent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:$packageName")
        }
        if (launchIntentIfPossible(exactAlarmIntent)) {
            return true
        }

        val appDetailsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
        return launchIntentIfPossible(appDetailsIntent)
    }

    private fun openSamsungBatterySettings(): Boolean {
        if (!isSamsungDevice()) {
            return false
        }

        // WHY(VECTOR 6): One UI may enforce additional app power controls that
        // are outside the standard AOSP battery optimization screen.
        val candidateIntents = listOf(
            Intent().setClassName(
                "com.samsung.android.lool",
                "com.samsung.android.sm.ui.battery.BatteryActivity",
            ),
            Intent("com.samsung.android.sm.ACTION_BATTERY"),
            Intent().setClassName(
                "com.samsung.android.lool",
                "com.samsung.android.sm.ui.appmanagement.AppManagementActivity",
            ),
        )

        for (intent in candidateIntents) {
            if (launchIntentIfPossible(intent)) {
                return true
            }
        }

        return openBatteryOptimizationSettings()
    }

    private fun launchIntentIfPossible(intent: Intent): Boolean {
        return try {
            val launchIntent = intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (launchIntent.resolveActivity(packageManager) == null) {
                false
            } else {
                startActivity(launchIntent)
                true
            }
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }
}
