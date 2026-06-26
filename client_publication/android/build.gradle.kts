// Fichier : android/build.gradle.kts

import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory
import com.android.build.gradle.AppExtension
import com.android.build.gradle.LibraryExtension

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.7.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Réorganisation du répertoire de build
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ✅ Dépendance entre modules
subprojects {
    project.evaluationDependsOn(":app")
}

// ✅ Tâche clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Forcer la même version NDK sur app + plugins natifs (pdfrx, etc.)
gradle.afterProject {
    extensions.findByType<AppExtension>()?.ndkVersion = "29.0.14033849"
    extensions.findByType<LibraryExtension>()?.ndkVersion = "29.0.14033849"
}
