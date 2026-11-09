import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Local builds use the ignored key.properties file; CI supplies one complete
// set of environment variables instead. Never mix credentials from both.
val signingVariables = mapOf(
    "storeFile" to "ANDROID_KEYSTORE_PATH",
    "storePassword" to "ANDROID_KEYSTORE_PASSWORD",
    "keyAlias" to "ANDROID_KEY_ALIAS",
    "keyPassword" to "ANDROID_KEY_PASSWORD",
)
val signingFromEnvironment = signingVariables.values.any {
    !System.getenv(it).isNullOrEmpty()
}
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = signingFromEnvironment || keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (signingFromEnvironment) {
        signingVariables.forEach { (property, variable) ->
            System.getenv(variable)?.let { setProperty(property, it) }
        }
    } else if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
if (hasReleaseSigning) {
    signingVariables.forEach { (property, variable) ->
        require(!keystoreProperties.getProperty(property).isNullOrBlank()) {
            "Missing Android signing setting: " +
                if (signingFromEnvironment) variable else "$property in android/key.properties"
        }
    }
}

android {
    namespace = "top.simonshiki.yukari"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "top.simonshiki.yukari"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // EasyTier supports arm64-v8a and x86_64; the release workflow passes
        // them via --target-platform, because an ndk.abiFilters list conflicts
        // with the splits AGP configures for --split-per-abi.

        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile")).also {
                    require(it.isFile) { "Android signing keystore does not exist or is not a file" }
                }
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
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
