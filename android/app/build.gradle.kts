plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.9.0"))

    implementation("com.google.firebase:firebase-analytics")
    implementation ("com.google.mlkit:face-mesh-detection:16.0.0-beta1")

    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
    implementation("com.google.protobuf:protobuf-kotlin-lite:3.24.0")
    implementation ("androidx.core:core:1.15.0")
    //implementation ("com.google.mediapipe:solution-core:latest.release")
    //implementation ("com.google.mediapipe:face_detection:latest.release")
    implementation ("com.google.mediapipe:tasks-vision:0.10.21")

}


android {
    namespace = "com.example.project_agila"
    compileSdk = 35
     // Match this with `flutter_face_api`



    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {

        jvmTarget = "17"// Change from "1.8" to "11"
    }

    packagingOptions {
        pickFirst ("lib/x86/libc++_shared.so")
        pickFirst ("lib/arm64-v8a/libc++_shared.so")
        pickFirst ("lib/armeabi-v7a/libc++_shared.so")
    }


    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.project_agila"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 30 // Adjust if needed
        targetSdk = 35
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


