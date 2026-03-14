# KWAN-TIME Release Notification Diagnosis Guide

## 0) Baseline Build Matrix
Run these in order so you can isolate Vector 1/10 first:

1. `flutter clean`
2. `flutter pub get`
3. `flutter build apk --release`
4. Install APK and test one reminder at `now + 2 minutes`.
5. If still broken, rebuild with shrinker enabled:
   `flutter build apk --release -Pkwan.enableShrinking=true`
6. Compare behavior. If only shrunk build fails, Vector 1/10 is primary.

## 1) Exact Alarm State (Vector 3)
Check if Android actually allows exact alarms for the app:

1. `adb shell appops get com.example.kwan_time SCHEDULE_EXACT_ALARM`
2. `adb shell dumpsys package com.example.kwan_time | findstr /i "SCHEDULE_EXACT_ALARM USE_EXACT_ALARM"`
3. `adb shell dumpsys alarm | findstr /i "com.example.kwan_time"`

Interpretation:

- No alarm rows for app after scheduling => scheduling path failed before AlarmManager.
- Alarm rows exist but marked inexact only => exact alarm permission is blocked.
- If blocked, open settings from app flow or manually:
  `adb shell am start -a android.settings.REQUEST_SCHEDULE_EXACT_ALARM -d package:com.example.kwan_time`

## 2) Notification Permission + Channel Integrity (Vector 4)
Check runtime notification gate and channel importance:

1. `adb shell cmd appops get com.example.kwan_time POST_NOTIFICATION`
2. `adb shell dumpsys notification --noredact | findstr /i "com.example.kwan_time kwan_reminders_v2 importance"`

Interpretation:

- POST_NOTIFICATION denied => reminders will not appear.
- Channel importance low/none => user or OS downgraded channel; app now recreates channel on schema mismatch.

## 3) Doze / Battery Optimization / Samsung Layers (Vector 6)
Inspect whether Samsung/AOSP power management is suppressing alarms:

1. `adb shell dumpsys deviceidle | findstr /i "mLightIdle mDeepIdle"`
2. `adb shell dumpsys deviceidle whitelist | findstr /i "com.example.kwan_time"`
3. `adb shell dumpsys power | findstr /i "Doze"`

If Samsung device:

1. Open Samsung battery controls through app path.
2. Confirm app is not in sleeping/deep sleeping list.
3. Re-test with screen off for at least 5 minutes.

## 4) Timezone Drift Validation (Vector 8)
If reminders fire hours late:

1. Schedule at local `now + 2 min`.
2. Compare expected local time vs. fired time.
3. Use logs:
   `adb logcat -v time | findstr /i "Timezone validation failed vector8TimezoneDrift"`

Interpretation:

- Drift of multiple hours indicates timezone resolution mismatch.
- Service now revalidates timezone during init and before scheduling.

## 5) Background Isolate / Callback Wiring (Vector 2/5/9)
Check if background callback registration path is present in release:

1. `adb logcat -v time | findstr /i "ActionBroadcastReceiver FlutterCallbackInformation callback"`
2. Tap notification action while app is killed.

Interpretation:

- If action tap logs show callback lookup failures, callback handles are missing.
- Current code registers background callback in `initialize()` using top-level
  `@pragma('vm:entry-point')` function.

## 6) R8/ProGuard Verification (Vector 1/10)
If shrinking build fails but non-shrinking build works:

1. Confirm release used `-Pkwan.enableShrinking=true`.
2. Check `proguard-rules.pro` is referenced by release build.
3. Rebuild and inspect logs:
   `adb logcat -v time | findstr /i "ClassNotFoundException NoSuchMethodError flutterlocalnotifications"`

## 7) Signing Differential (Vector 7)
Samsung can behave differently between debug-signed and production-signed APKs:

1. Test debug-signed release (current Gradle config).
2. Test production-signed release.
3. Verify certs:
   `apksigner verify --print-certs app-release.apk`

Interpretation:

- If only one signature fails, focus on permission/app-op state tied to package+signature.

## 8) Fastest Resolution Order
Use this exact order:

1. Vector 10/1: non-shrunk release vs shrunk release.
2. Vector 3: exact alarm capability + app-op.
3. Vector 6: Samsung + Doze restrictions.
4. Vector 4: channel integrity.
5. Vector 8: timezone drift.
6. Vector 2/5/9: background callback wiring.
7. Vector 7: signing comparison.

This order finds root cause fastest on Samsung Android 12+ devices.
