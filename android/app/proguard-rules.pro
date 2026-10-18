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

# package:jni looks up Kotlin methods by exact JNI signature (e.g. shared_preferences
# getAll(String, List, Continuation)), so the types in those signatures must keep their names.
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.jvm.functions.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-dontwarn com.github.dart_lang.jni.**

# Preserve annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
