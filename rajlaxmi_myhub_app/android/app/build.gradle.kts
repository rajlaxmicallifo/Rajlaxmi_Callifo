plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.rajlaxmi_myhub_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ Java 17 support
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // ✅ Enable core library desugaring (required for call_log, etc.)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.rajlaxmi_myhub_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ✅ Required for some libraries
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Using debug signing for now
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += setOf("/META-INF/{AL2.0,LGPL2.1}")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Fixes your error: call_log needs 2.1.4 or higher
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // ✅ Kotlin standard library
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")

    // ✅ Enable multidex support for larger apps
    implementation("androidx.multidex:multidex:2.0.1")
}
