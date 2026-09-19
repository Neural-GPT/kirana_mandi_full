# Flutter's own engine/plugin classes are already covered by the
# default `proguard-android-optimize.txt` + the Flutter Gradle plugin's
# built-in rules -- this file is only for rules specific to this app.
# Add -keep rules here if a release build crashes with a
# ClassNotFoundException/NoSuchMethodError after enabling minifyEnabled
# (usually meaning something used only via reflection, e.g. a plugin's
# platform channel model class, got stripped).

# Keep the sqflite/path_provider/geolocator plugin classes we call into.
-keep class io.flutter.plugins.** { *; }
