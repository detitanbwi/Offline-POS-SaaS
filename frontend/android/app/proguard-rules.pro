# Flutter-specific ProGuard rules
# Keep Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }

# Keep Bluetooth Thermal Printer classes
-keep class com.example.print_bluetooth_thermal.** { *; }

# Keep SQLCipher
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Keep Android ID plugin
-keep class com.AidenJohnson.android_id.** { *; }

# Keep Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep Device Info Plus
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# Suppress warnings for common libraries
-dontwarn com.google.**
-dontwarn org.apache.**
