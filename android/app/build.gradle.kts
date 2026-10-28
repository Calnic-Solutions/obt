plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.oralogos"
    // permission_handler 13 will not build against anything older. Compiling
    // against 37 changes nothing about which phones can install the app -
    // that is minSdk - or how it behaves on them, which is targetSdk.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.oralogos"
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // The file the person downloads is named for the app and its version,
    // "LIVUKA-0.1.1-arm64-v8a.apk", not "app-arm64-v8a-release.apk":
    // the manual tells them to look for LIVUKA-x.y.z.apk, and a build
    // split by processor still says which one it is.
    applicationVariants.all {
        val variant = this
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val abi = output.getFilter(com.android.build.OutputFile.ABI)
            val suffix = if (abi == null) "" else "-$abi"
            val kind = if (variant.buildType.name == "release") "" else "-${variant.buildType.name}"
            output.outputFileName = "LIVUKA-${variant.versionName}$suffix$kind.apk"
        }
        // Flutter copies each APK into build/app/outputs/flutter-apk under
        // its own fixed name, "app-<abi>-<mode>.apk", and that is the path
        // it prints. The named file is put there beside it, so the folder
        // a person opens after `flutter build apk` has it.
        val named = variant.outputs.map { it.outputFile }
        variant.assembleProvider.get().doLast {
            named.forEach { file ->
                copy {
                    from(file)
                    into(layout.buildDirectory.dir("outputs/flutter-apk"))
                }
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
