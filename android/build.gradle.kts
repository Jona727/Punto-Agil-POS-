allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Plugins antiguos (flutter_vibrate, flutter_bluetooth_serial) traen un compileSdk
// viejo y/o no declaran namespace; AGP moderno falla con ellos. Se corrige acá,
// una sola vez, sin tocar el caché de pub. Debe ir ANTES de evaluationDependsOn.
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            extensions.findByName("android")?.let {
                extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                    if (namespace == null) {
                        namespace = project.group.toString()
                    }
                    compileSdkVersion(36)
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
