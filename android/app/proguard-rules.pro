# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# home_widget
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# sqflite
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# flutter_dotenv
-keep class io.flutter.plugins.flutter_plugin_android_lifecycle.** { *; }

# Kotlin coroutines
-keepnames class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Preserve annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
