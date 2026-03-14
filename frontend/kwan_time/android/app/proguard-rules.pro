# WHY(VECTOR 1, VECTOR 10): Keep all flutter_local_notifications classes,
# including receivers/services/models referenced through reflection/Intents.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.isolate.** { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ForegroundService { *; }

# WHY(VECTOR 1): Keep Flutter timezone plugin classes used during bootstrap.
-keep class net.wolverinebeach.flutter_timezone.** { *; }

# WHY(VECTOR 5, VECTOR 9): Keep Flutter background-isolate callback plumbing.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class io.flutter.embedding.engine.FlutterEngine { *; }
-keep class io.flutter.embedding.engine.loader.** { *; }
-keep class io.flutter.embedding.engine.dart.DartExecutor { *; }
-keep class io.flutter.embedding.engine.dart.DartExecutor$DartCallback { *; }
-keep class io.flutter.view.FlutterCallbackInformation { *; }
-keep class io.flutter.FlutterInjector { *; }
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.EventChannel { *; }

# WHY(VECTOR 1): Notification internals deserialize JSON payloads via Gson.
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# WHY(VECTOR 1): Keep framework receiver/service subclasses against aggressive renaming.
-keep class * extends android.content.BroadcastReceiver { *; }
-keep class * extends android.app.Service { *; }

# WHY(VECTOR 1): Preserve runtime metadata used by reflection and @Keep.
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# WHY(VECTOR 8): Keep java.time backport/desugaring classes if bundled.
-keep class j$.time.** { *; }
-dontwarn j$.time.**
