import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services plugin for Firebase (required for OneSignal push notifications)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.milkman.mealvanaendurance"
    compileSdk = 36  // Required by app_links, geolocator, google_sign_in, etc.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11

        // Enable desugaring for java.time APIs (required for scheduled notifications on Android 14+)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.milkman.mealvanaendurance"
        minSdk = flutter.minSdkVersion  // Matches pubspec.yaml flutter_launcher_icons config
        targetSdk = 34  // Google Play requirement (will require 35 by Aug 2025)
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Enable MultiDex for notification library (may exceed 64K method limit)
        multiDexEnabled = true
    }

    // Release signing configuration - must be defined BEFORE buildTypes
    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                val keystoreProperties = Properties()
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))

                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Release signing configuration
            // To generate keystore: keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
            // Then create android/key.properties with storePassword, keyPassword, keyAlias, storeFile
            signingConfig = signingConfigs.getByName("release")

            // R8 code shrinking and obfuscation (enabled by default)
            // Reduces APK size by ~30-40%, adds basic obfuscation
            // All packages in this project support R8
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // Core library desugaring for java.time APIs on older Android versions
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
