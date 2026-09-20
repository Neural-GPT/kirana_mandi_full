import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- White-label build parameters ---
// Passed by CI (see .github/workflows/build_apk.yml) as Gradle project
// properties so a shop-specific build changes the app at the SYSTEM
// level -- launcher label and Android package id -- not just inside
// Dart/Flutter. Defaults keep a normal `flutter run`/multi-shop build
// working unchanged.
//
//   flutter build apk -PshopAppId=com.kiranamandi.shop.sabc12345 \
//                      -PshopAppLabel="Sharma General Store" \
//                      --dart-define=SHOP_ID=... --dart-define=APP_NAME=...
//
// shopAppId MUST be unique per shop: Android treats the applicationId as
// the app's identity, so two shops sharing one id would install as the
// SAME app (the second install overwrites the first) instead of two
// separate apps a customer can keep side by side. See the workflow for
// how it's derived from shop_id.
val shopAppId: String = (project.findProperty("shopAppId") as String?)
    ?: System.getenv("SHOP_APP_ID")
    ?: "com.example.kirana_mandi"
val shopAppLabel: String = (project.findProperty("shopAppLabel") as String?)
    ?: System.getenv("SHOP_APP_LABEL")
    ?: "Kirana Mandi"

android {
    namespace = "com.example.kirana_mandi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Unique per shop-specific build (see shopAppId above); left as
        // the shared example id for a normal multi-shop/dev build.
        applicationId = shopAppId
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Read by AndroidManifest.xml's android:label="${appLabel}" --
        // this is what actually renames the app on the home screen /
        // app drawer / Settings > Apps, as opposed to EnvConfig.appName
        // which only affects in-app text (MaterialApp.title, etc).
        manifestPlaceholders["appLabel"] = shopAppLabel
    }

    signingConfigs {
        // Optional real release signing: create android/key.properties
        // (gitignored) with storeFile/storePassword/keyAlias/keyPassword
        // to sign white-label release builds with your own key instead
        // of the debug key. Falls back to the debug key when absent so
        // `flutter run --release` and CI builds without a configured
        // keystore keep working exactly as before.
        val keystorePropertiesFile = rootProject.file("key.properties")
        if (keystorePropertiesFile.exists()) {
            val keystoreProperties = Properties()
            keystoreProperties.load(FileInputStream(keystorePropertiesFile))
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signingConfigs.findByName("release") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Shrinks + obfuscates code and strips unused resources --
            // meaningfully smaller APKs (faster download/install) and a
            // smaller method count. Combined with --split-per-abi in the
            // build command, this is most of the "APK weight" half of
            // the performance ask; the rest is app-side (see
            // PERFORMANCE.md at the repo root).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}