# Keep WebView and Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class android.webkit.** { *; }
-keep class androidx.webkit.** { *; }

# Don't warn about missing classes from optional packages
-dontwarn android.webkit.**
-dontwarn androidx.webkit.**
