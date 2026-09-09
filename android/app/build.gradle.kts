plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle plugin must be applied after android/kotlin.
    id("dev.flutter.flutter-plugin-loader")
}

android {
    namespace = "com.jessicacarter.chocoblock"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.jessicacarter.chocoblock"
        minSdk = 21                       // webview_flutter requires 21+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // For now sign with the debug key so the release APK installs
            // without needing a keystore. For Play Store publishing,
            // replace with a real keystore via GitHub Secrets.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packagingOptions {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.webkit:webkit:1.11.0")
}
