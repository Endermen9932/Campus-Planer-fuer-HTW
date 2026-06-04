pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("com.android.application") version "8.1.0" apply false
    id("com.android.library") version "8.1.0" apply false
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
    id("org.jetbrains.kotlin.android") version "1.7.10" apply false
}

include(":app")
