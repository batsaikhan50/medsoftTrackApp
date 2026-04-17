# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# App classes
-keep class com.batsaikhan.medsofttrack.** { *; }

# OkHttp
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Google Play Services (Location)
-keep class com.google.android.gms.location.** { *; }

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# Keep JSON model fields from being stripped
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Prevent stripping of line numbers for crash reports
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
