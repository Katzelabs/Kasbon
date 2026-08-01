import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload-key credentials, kept out of the repo. Create `android/key.properties`
// (gitignored) with keyAlias / keyPassword / storeFile / storePassword; see the
// "Release signing" section of app/CLAUDE.md for how to generate the keystore.
//
// Absent, the release build falls back to the debug keystore so that
// `flutter run --release` still works on a fresh clone. That fallback is for
// local runs only - Play rejects a debug-signed upload, and the signing key is
// not rotatable after the first release, so a build meant for distribution must
// have this file present. The `signingReport` line below is what tells you which
// of the two you actually got.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasUploadKey = keystorePropertiesFile.exists()

android {
    namespace = "com.kasbon.pos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.kasbon.pos"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "KASBON: android/key.properties not found - signing the " +
                        "release build with the DEBUG key. Fine for a local " +
                        "`flutter run --release`; Google Play will reject it."
                )
                signingConfigs.getByName("debug")
            }

            // R8: shrink the Java/Kotlin half of the app.
            //
            // Dart is AOT-compiled into libapp.so and untouched by this; what
            // R8 strips is the Flutter embedding and each plugin's Android
            // code. Measured with everything else held equal - same flags, same
            // env file, both --obfuscate - it is worth 3.02 MB: 61.35 down to
            // 58.33.
            //
            // Measure it that way or not at all. An earlier comparison here
            // read 63.1 MB minified against 62.4 unminified and concluded R8
            // made the APK bigger; those two builds differed in --obfuscate,
            // and the comparison meant nothing.
            //
            // Off by default in the Flutter template for a good reason. R8
            // deletes whatever it cannot see referenced, and reflection is
            // invisible to it, so this is the setting most likely to build
            // clean and fail at runtime - which is exactly what it did here.
            // The first minified APK installed, launched, held its process
            // alive, reported MainActivity as topResumedActivity, and drew a
            // black screen, with no exception anywhere in logcat. Do not trust
            // a successful build. Install it and look at it.
            // See proguard-rules.pro for what it had removed.
            isMinifyEnabled = true

            // Resource shrinking stays off. Flutter keeps its assets in assets/
            // rather than res/, so there is little here for it to remove, and
            // it removes by the same static-reference analysis that produced
            // the black screen above - failing next time as a missing drawable
            // on some screen nobody happened to open while testing. Not worth
            // it for the remaining few hundred KB.
            isShrinkResources = false

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
