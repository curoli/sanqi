plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release credentials come from the environment, never from source control.
val uploadStorePath = providers.environmentVariable("SANQI_ANDROID_KEYSTORE_PATH").orNull
val uploadStorePassword = providers.environmentVariable("SANQI_ANDROID_STORE_PASSWORD").orNull
val uploadKeyAlias = providers.environmentVariable("SANQI_ANDROID_KEY_ALIAS").orNull
val uploadKeyPassword = providers.environmentVariable("SANQI_ANDROID_KEY_PASSWORD").orNull
val hasUploadSigning = listOf(
    uploadStorePath, uploadStorePassword, uploadKeyAlias, uploadKeyPassword,
).all { !it.isNullOrEmpty() }
// Inspect the resolved graph so aggregate tasks such as `build` are guarded too.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("release", ignoreCase = true) } && !hasUploadSigning) {
        throw GradleException(
            "Release signing requires SANQI_ANDROID_KEYSTORE_PATH, " +
                "SANQI_ANDROID_STORE_PASSWORD, SANQI_ANDROID_KEY_ALIAS, and " +
                "SANQI_ANDROID_KEY_PASSWORD. See docs/android-release.md.",
        )
    }
}

android {
    namespace = "com.curoli.flutter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.curoli.sanqi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadSigning) {
            create("upload") {
                storeFile = file(uploadStorePath!!)
                storePassword = uploadStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Missing credentials must never silently produce a debug-signed release.
            signingConfig = signingConfigs.findByName("upload")
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
