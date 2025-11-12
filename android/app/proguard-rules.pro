# Mealvana Endurance - ProGuard Rules for Release Builds
# Generated for v1.9.0+30 Android deployment

# Flutter-specific rules (automatically included by Flutter plugin)
# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Supabase/Postgrest - Keep reflection-based classes
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }
-dontwarn io.supabase.**
-dontwarn com.supabase.**

# Drift Database - Keep generated classes
-keep class drift.** { *; }
-keepclassmembers class * extends drift.** { *; }

# Sentry - Automatically handled by sentry_flutter plugin
# Rules bundled in plugin since v9.0.0

# RudderStack Analytics - Automatically handled
# Rules bundled in rudder_sdk_flutter since v1.20.0

# Gson (used by Supabase) - Keep generic signatures
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# OkHttp (used by Supabase, Sentry) - Keep platform classes
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Kotlin Coroutines (used by Supabase)
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.** {
    volatile <fields>;
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom application classes
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep Parcelables
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializables
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
