# FinRoot Android — R8 / ProGuard keep rules (M20).
#
# Only consulted when code shrinking is enabled (isMinifyEnabled = true in
# build.gradle.kts). Shrinking is OFF by default because the native plugin set
# has not been verified on a device — turn it on only alongside a real device
# smoke test (docs/RELEASE.md, M19 §5 checklist).
#
# Flutter's own default rules (flutter_proguard_rules.pro, bundled with the
# Flutter Gradle plugin) already keep the embedding and io.flutter.**. The rules
# below cover the plugins this app adds.

# --- flutter_local_notifications (M12) ---
# Uses Gson-style reflection for scheduled-notification payloads and needs its
# receivers kept for boot re-scheduling.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*
# Desugared java.time used on minSdk < 26.
-dontwarn java.time.**
-dontwarn com.google.gson.**

# --- workmanager (M5) ---
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# --- speech_to_text (M14) ---
-keep class com.csdcorp.speech_to_text.** { *; }

# --- sqlite3 / SQLite3MultipleCiphers (M4) ---
# Loaded through JNI by the `sqlite3` Dart package; keep the loader shims.
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# --- flutter_secure_storage (M3/M4) ---
-keep class io.flutter.plugins.fluttersecurestorage.** { *; }

# --- Supabase / OkHttp (transitive, supabase_flutter) ---
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
