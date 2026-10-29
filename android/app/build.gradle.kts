import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (M20). Credentials live in android/key.properties, which is
// git-ignored — see android/key.properties.example and docs/RELEASE.md. When the
// file is absent (this dev machine, CI without secrets) the release build falls
// back to the debug keystore so `flutter build`/`flutter run --release` still
// work; a store-bound artifact is only produced when key.properties is present.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.finroot.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (M12) for java.time on
        // minSdk < 26. DEVICE-UNVERIFIED — no Android SDK to build with yet.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.finroot.mobile"
        // Flutter's own floor (24, Android 7.0); the Flutter tool rewrote the
        // earlier hard-coded 23. Still covers flutter_secure_storage (StrongBox /
        // EncryptedSharedPreferences), local_auth biometrics, and SQLCipher.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    // Payment detection needs notification access, which Play Protect blocks
    // for side-loaded apps in India. Release builds leave its service out
    // unless built with -Pfinroot.paymentDetection=true (see the overlay
    // manifest in src/noPaymentDetection/). Debug builds keep it.
    if (project.findProperty("finroot.paymentDetection")?.toString() != "true") {
        sourceSets.maybeCreate("release").manifest.srcFile("src/noPaymentDetection/AndroidManifest.xml")
        sourceSets.maybeCreate("profile").manifest.srcFile("src/noPaymentDetection/AndroidManifest.xml")
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties — keep the debug keystore so release builds
                // still compile on machines without the signing secrets.
                signingConfigs.getByName("debug")
            }
            // Code shrinking (R8) is left OFF by default: the native plugin set
            // (flutter_local_notifications, workmanager, speech_to_text, sqlite3)
            // has never been exercised on a device, so a stripped build is
            // unverifiable here. proguard-rules.pro carries the keep rules for
            // when a device owner turns shrinking on — see docs/RELEASE.md.
            isMinifyEnabled = false
            // Resource shrinking needs R8 on; AGP 9 refuses it alone.
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
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

dependencies {
    // See isCoreLibraryDesugaringEnabled above (flutter_local_notifications, M12).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
