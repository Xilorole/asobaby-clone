# Keep the application entry point
-keep class dev.asobaby.app.MainActivity { *; }

# Keep model classes used with JSON parsing
-keep class dev.asobaby.app.Release { *; }

# AndroidX / Material
-keep class androidx.core.content.FileProvider { *; }
-dontwarn com.google.android.material.**
-keep class com.google.android.material.** { *; }

# Kotlinx coroutines
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }

# Keep standard Android components
-keep public class * extends android.app.Activity
-keep public class * extends android.content.ContentProvider
