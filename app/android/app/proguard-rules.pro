# R8 keep rules for the release build.
#
# Only what R8 cannot work out for itself belongs here. Flutter's own rules and
# every plugin's consumer rules are merged in automatically by AGP, so this file
# covers the gaps those leave - which in practice means code reached by
# reflection, since R8 sees a reflective lookup as no reference at all and
# deletes the target.
#
# Anything added here should say which dependency needs it and why, because a
# keep rule that has outlived its cause is invisible dead weight - it just makes
# the APK quietly bigger forever.

# --- Flutter embedding --------------------------------------------------------
# GeneratedPluginRegistrant reaches every plugin's *Plugin class by name, and
# the engine resolves parts of io.flutter.** reflectively from native code. R8
# sees neither, so without this the APK builds cleanly and then shows a black
# screen: the engine attaches, plugin registration fails, and Dart never paints.
# There is no exception in logcat - only "FlutterJNI was detached from native
# C++" - which is why this cost a build-and-install cycle to find.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.kasbon.pos.** { *; }

# --- Tink, via flutter_secure_storage -----------------------------------------
# EncryptedSharedPreferences (androidx.security.crypto) is backed by Google
# Tink, which resolves key managers and proto types reflectively from string
# names. R8 cannot see those references, strips the classes, and the failure
# surfaces at runtime as a GeneralSecurityException the first time a session is
# read - i.e. on relaunch, not on the launch that wrote it. This is the rule
# this app most needs, because the session store depends on it.
-keep class com.google.crypto.tink.** { *; }
-keepclassmembers class * extends com.google.crypto.tink.shaded.protobuf.GeneratedMessageLite { *; }
-dontwarn com.google.crypto.tink.**
-dontwarn com.google.api.client.http.**
-dontwarn org.joda.time.**

# --- Error Prone / JSR-305 annotations ----------------------------------------
# Pulled in transitively by the above. Compile-time only, absent at runtime, and
# R8 warns about the dangling references unless told not to.
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.annotations.**

# --- Play Core, via Flutter's deferred-components support ----------------------
# Flutter's embedding references SplitCompat and friends even when the app does
# not use deferred components, and this app does not, so the library is absent.
-dontwarn com.google.android.play.core.**

# --- Kotlin coroutines --------------------------------------------------------
# The debug probes are looked up by name and the service loader files are data,
# not code. Harmless to keep and awkward to debug when missing.
-dontwarn kotlinx.coroutines.**
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
