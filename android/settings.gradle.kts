pluginManagement {
    val flutterSdkPath =
        run {
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
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")

// maplibre_gl 0.27.0 skips `kotlin-android` when AGP is 9+, assuming
// built-in Kotlin is on. Flutter 3.44 keeps `android.builtInKotlin=false`,
// so the plugin's `kotlin { }` block has no extension and evaluation
// fails with "Could not find method kotlin()". Apply KGP first.
// Remove when maplibre_gl applies KGP whenever builtInKotlin != true.
gradle.beforeProject {
    if (name == "maplibre_gl") {
        pluginManager.apply("org.jetbrains.kotlin.android")
    }
}
