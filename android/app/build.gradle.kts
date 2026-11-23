import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.dobby.assetallocation"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = keyProperties["storeFile"]?.let { file(it) }
            storePassword = keyProperties["storePassword"] as String
        }
    }

    defaultConfig {
        applicationId = "com.dobby.assetallocation"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // R8 난독화·축소는 Flutter 기본값으로도 돌지만, 리소스 축소는
            // 켜져 있지 않아 실제로 제거되는 리소스가 0개였다. 둘 다 명시한다.
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Force latest androidx.datastore compiled with NDK r28 (16KB page size fix)
    implementation("androidx.datastore:datastore-core:1.1.7")
    implementation("androidx.datastore:datastore-preferences-core:1.1.7")
    // WindowCompat for Android 15+ edge-to-edge wider screen support
    implementation("androidx.core:core-ktx:1.15.0")
}

configurations.all {
    resolutionStrategy {
        force("androidx.datastore:datastore-core:1.1.7")
        force("androidx.datastore:datastore-preferences-core:1.1.7")
    }
}
