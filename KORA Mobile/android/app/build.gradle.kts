import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

// A release build is only signed with the upload key when that key is actually here.
//
// key.properties is not in the repository — it holds passwords — and neither is the keystore
// it points at, so on any machine but the one that owns the key, `flutter build apk --release`
// used to fail at validateSigningRelease before it built anything. That is the wrong failure:
// a release build is useful for testing long before there is a key to publish under. Without
// the keystore the build falls back to the debug signature, which installs and runs but is
// not a store-publishable artefact. Put the keystore where key.properties points and the
// upload signature comes back with no further change.
val releaseKeystore = keyProperties["storeFile"]?.toString()?.let { file(it) }
val hasUploadKey = releaseKeystore?.exists() == true

android {
    namespace = "com.kora.wallet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile     = releaseKeystore
                storePassword = keyProperties["storePassword"]?.toString()
                keyAlias      = keyProperties["keyAlias"]?.toString()
                keyPassword   = keyProperties["keyPassword"]?.toString()
            }
        }
    }

    defaultConfig {
        applicationId = "com.kora.wallet"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
