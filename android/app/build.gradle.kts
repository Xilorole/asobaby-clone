import java.util.Properties
import java.time.LocalDate
import java.time.format.DateTimeFormatter

plugins {
    id("com.android.application")
    id("kotlin-android")
}

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

// ─── CalVer Versioning ─────────────────────────────────────────────
// Format: YYYY.MMDD.patch  (e.g. 2026.0308.0)
// versionCode: YYYYMMDD * 100 + patch  (e.g. 2026030800)
// Override via gradle properties: -PcalverPatch=1 or env CAL_VERSION / CAL_VERSION_CODE
val today: LocalDate = LocalDate.now()
val calverDate = today.format(DateTimeFormatter.ofPattern("yyyy.MMdd"))
val patch = (project.findProperty("calverPatch") as? String)?.toIntOrNull() ?: 0

val calVersionName: String = System.getenv("CAL_VERSION")
    ?: "$calverDate.$patch"
val calVersionCode: Int = System.getenv("CAL_VERSION_CODE")?.toIntOrNull()
    ?: (today.year * 10000 + today.monthValue * 100 + today.dayOfMonth) * 100 + patch

android {
    namespace = "dev.asobaby.app"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "dev.asobaby.app"
        minSdk = 24
        targetSdk = 35
        versionCode = calVersionCode
        versionName = calVersionName
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            isDebuggable = true
            // Debug builds get a distinct app label so both can be installed
            manifestPlaceholders["appLabel"] = "Asobaby Dev"
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            manifestPlaceholders["appLabel"] = "Asobaby"
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (signingConfigs.names.contains("release")) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
