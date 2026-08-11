import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = project.file("key.properties")
val signingProperties = Properties()
if (signingPropertiesFile.exists()) {
    signingProperties.load(FileInputStream(signingPropertiesFile))
}
val storeFilePath = signingProperties.getProperty("storeFile")
val storePasswordValue = signingProperties.getProperty("storePassword")
val keyAliasValue = signingProperties.getProperty("keyAlias")
val keyPasswordValue = signingProperties.getProperty("keyPassword")
val storeTypeValue = signingProperties.getProperty("storeType", "pkcs12")

android {
    namespace = "com.usedphone.usedphone"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.usedphone.usedphone"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.create("release") {
                require(!storeFilePath.isNullOrBlank()) { "Missing storeFile in android/key.properties" }
                require(!storePasswordValue.isNullOrBlank()) { "Missing storePassword in android/key.properties" }
                require(!keyAliasValue.isNullOrBlank()) { "Missing keyAlias in android/key.properties" }
                require(!keyPasswordValue.isNullOrBlank()) { "Missing keyPassword in android/key.properties" }
                val keystoreFile = project.file(storeFilePath!!)
                require(keystoreFile.exists()) { "Keystore not found: ${keystoreFile.absolutePath}" }
                storeFile = keystoreFile
                storePassword = storePasswordValue
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
                storeType = storeTypeValue
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
