import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.talkingcards.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Paid-pack content ships as a Play asset pack (fast-follow) instead of
    // inflating the base download — see android/content_pack and
    // tools/pad_split.py.
    assetPacks += listOf(":content_pack")

    defaultConfig {
        applicationId = "com.talkingcards.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// Flutter copies assets/pad_content into flutter_assets like everything else
// in pubspec — its copyFlutterAssets<Variant> task runs *after* AGP's asset
// merge and writes straight into the merged output, which is why neither
// androidResources.ignoreAssetsPattern nor a hook on mergeAssets can catch
// it. For app bundles the directory is removed right after that copy, so
// Play does not ship it twice; the :content_pack module carries it. Only for
// bundle tasks: a debug APK from `flutter run` keeps everything in one place
// and never talks to Play, which is what AssetPackService's marker check
// detects.
if (gradle.startParameter.taskNames.any { it.contains("bundle", ignoreCase = true) }) {
    tasks.matching { it.name.startsWith("copyFlutterAssets") }.configureEach {
        outputs.upToDateWhen { false }
        doLast {
            val pad = (this as Copy).destinationDir.resolve("flutter_assets/assets/pad_content")
            if (pad.exists()) {
                pad.deleteRecursively()
                logger.lifecycle("PAD: stripped pad_content from base (ships in :content_pack)")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.engage:engage-core:1.5.4")
    // Play Asset Delivery client — AssetPacks.kt
    implementation("com.google.android.play:asset-delivery:2.3.0")
}

flutter {
    source = "../.."
}
