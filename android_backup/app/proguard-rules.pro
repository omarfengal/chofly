# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Gson / JSON
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

# Keep model classes
-keep class com.chofly.app.** { *; }
