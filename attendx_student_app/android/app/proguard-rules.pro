# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Dio / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# Local Auth (biometrics)
-keep class androidx.biometric.** { *; }

# Safe Device
-keep class com.dexterous.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Mobile Scanner (QR)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Sqflite
-keep class io.flutter.plugins.sqflite.** { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep all model classes (Dart uses reflection-like serialization)
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
