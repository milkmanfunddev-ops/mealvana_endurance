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
        targetSdk = 36  // Google Play requires targeting Android 16 (API 36) by Aug 31, 2026
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Enable MultiDex for notification library (may exceed 64K method limit)
        multiDexEnabled = true

        // Patrol integration testing
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    // Signing configurations - defined before flavors and buildTypes
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

    // Product flavors for dev/prod environments
    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Endurance Dev")
            manifestPlaceholders["oauthCallbackScheme"] = "com.milkman.mealvanaendurance.dev"
            // Dev flavor: always use debug keystore
            signingConfig = signingConfigs.getByName("debug")
        }

        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "Endurance")
            manifestPlaceholders["oauthCallbackScheme"] = "com.milkman.mealvanaendurance"
            // Prod flavor: always use release keystore (upload key)
            // so debug and release builds have the same SHA-1 for OAuth
            signingConfig = signingConfigs.getByName("release")
        }
    }

    buildTypes {
        debug {
            // Let flavor signing configs take effect instead of default debug keystore
            signingConfig = null
        }
        release {
            signingConfig = signingConfigs.getByName("release")

            // R8 code shrinking and obfuscation
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

    // Patrol integration testing — Android Test Orchestrator
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}

flutter {
    source = "../.."
}
