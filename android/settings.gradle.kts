pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // 8.11.1 = Flutter >=3.44 minimum AGP (2026-08); 8.9.1+ was required by androidx.core 1.18 /
    // navigationevent 1.0.2 via image_picker 1.2.2 (release build failed on 8.7.3).
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // Google Services plugin for Firebase (required for OneSignal push notifications)
    id("com.google.gms.google-services") version "4.4.2" apply false
    // Sentry Gradle plugin: stamps an R8 mapping UUID into the bundle so the
    // mapping.txt that codemagic.yaml's &upload_sentry_symbols uploads can be
    // matched to events. Upload itself is OFF here (see app/build.gradle.kts).
    id("io.sentry.android.gradle") version "6.23.0" apply false
}

include(":app")
