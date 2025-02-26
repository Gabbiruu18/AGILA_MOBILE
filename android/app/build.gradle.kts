plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")


}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.9.0"))

    // Firebase Dependencies
    implementation("com.google.firebase:firebase-analytics")

    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
    implementation("com.google.protobuf:protobuf-kotlin-lite:3.24.0")
    implementation ("androidx.core:core:1.9.0")
}


android {
    namespace = "com.example.project_agila"
    compileSdk = 34



    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11" // Change from "1.8" to "11"
    }


    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.project_agila"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 30 // Adjust if needed
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName


    }



    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}


