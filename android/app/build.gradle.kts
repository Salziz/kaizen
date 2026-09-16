import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun signingProp(key: String, environmentVariable: String): String? =
    keystoreProperties.getProperty(key)?.takeIf(String::isNotBlank)
        ?: System.getenv(environmentVariable)?.takeIf(String::isNotBlank)

val releaseSigningProperties = mapOf(
    "keyAlias" to signingProp("keyAlias", "KAIZEN_KEY_ALIAS"),
    "keyPassword" to signingProp("keyPassword", "KAIZEN_KEY_PASSWORD"),
    "storeFile" to signingProp("storeFile", "KAIZEN_STORE_FILE"),
    "storePassword" to signingProp("storePassword", "KAIZEN_STORE_PASSWORD"),
)
val configuredReleaseSigningProperties = releaseSigningProperties.values.count { it != null }
if (configuredReleaseSigningProperties !in listOf(0, releaseSigningProperties.size)) {
    error(
        "Incomplete release-signing configuration. Set all four properties in " +
            "android/key.properties or all KAIZEN_* environment variables."
    )
}
val hasReleaseSigning = configuredReleaseSigningProperties == releaseSigningProperties.size
val allowDebugReleaseSigning =
    System.getenv("KAIZEN_ALLOW_DEBUG_RELEASE_SIGNING") == "true"

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.salziz.kaizen.kaizen"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.salziz.kaizen.kaizen"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Two-major-version floor (Android 16 = API 36) computes to API 34.
        // Tested against API 31 (Android 12), which clears that floor with margin.
        // This intentionally drops Android 7–11 (API 24–30) from the install base —
        // acceptable for this stage, revisit once real device-distribution data
        // is available (see open question on TFS-001).
        minSdk = 31
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = releaseSigningProperties["keyAlias"]
            keyPassword = releaseSigningProperties["keyPassword"]
            storeFile = releaseSigningProperties["storeFile"]?.let(::file)
            storePassword = releaseSigningProperties["storePassword"]
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else if (allowDebugReleaseSigning) {
                logger.warn(
                    "DEBUG-SIGNED RELEASE APK: non-distributable. See README.md for " +
                        "production signing setup."
                )
                signingConfigs.getByName("debug")
            } else {
                null
            }
        }
    }
}

tasks.configureEach {
    if (name == "assembleRelease" || name == "bundleRelease" || name == "packageRelease") {
        doFirst {
            if (!hasReleaseSigning && !allowDebugReleaseSigning) {
                error(
                    "No release signing configuration found. Set all four properties in " +
                        "android/key.properties or all KAIZEN_* environment variables. " +
                        "For a local release-mode inspection build only, set " +
                        "KAIZEN_ALLOW_DEBUG_RELEASE_SIGNING=true."
                )
            }
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
