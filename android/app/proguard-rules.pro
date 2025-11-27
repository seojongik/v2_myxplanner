# Firebase Core
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Flutter Firebase Plugins
-keep class io.flutter.plugins.firebase.** { *; }
-dontwarn io.flutter.plugins.firebase.**

# Keep Firebase initialization
-keep class com.google.firebase.FirebaseApp { *; }
-keep class com.google.firebase.FirebaseOptions { *; }

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Flutter engine classes
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

