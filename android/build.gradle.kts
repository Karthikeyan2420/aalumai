allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some older Flutter plugins (e.g. on_audio_query_android 1.1.0) predate AGP 7's
// `namespace` requirement and only declare a package in their AndroidManifest.
// AGP 8 fails the whole build for such modules, so back-fill the namespace from
// the manifest package while the Android library plugin is being configured.
subprojects {
    plugins.withId("com.android.library") {
        val android = extensions.findByName("android") ?: return@withId

        val manifest = projectDir.resolve("src/main/AndroidManifest.xml")
        val current = android.javaClass.methods
            .firstOrNull { it.name == "getNamespace" && it.parameterCount == 0 }
            ?.invoke(android) as? String
        if (current.isNullOrEmpty() && manifest.exists()) {
            val namespace = Regex("package=\"([^\"]+)\"")
                .find(manifest.readText())
                ?.groupValues?.get(1)
            if (namespace != null) {
                android.javaClass.methods
                    .firstOrNull {
                        it.name == "setNamespace" &&
                            it.parameterCount == 1 &&
                            it.parameterTypes[0] == String::class.java
                    }
                    ?.invoke(android, namespace)
            }
        }

        // Force Java 17 on every Android library so AGP 8 JVM-target checks
        // stay aligned with Kotlin when Gradle runs on JDK 22+.
        val compileOptions = android.javaClass.methods
            .firstOrNull { it.name == "getCompileOptions" && it.parameterCount == 0 }
            ?.invoke(android)
        if (compileOptions != null) {
            listOf("setSourceCompatibility", "setTargetCompatibility").forEach { setter ->
                compileOptions.javaClass.methods
                    .firstOrNull {
                        it.name == setter &&
                            it.parameterCount == 1 &&
                            it.parameterTypes[0] == JavaVersion::class.java
                    }
                    ?.invoke(compileOptions, JavaVersion.VERSION_17)
            }
        }
    }

}

// After every plugin script has configured itself, force JVM 17 on Java and
// Kotlin compile tasks. Needed when Gradle runs on JDK 22+ and plugins pin
// different targets (1.8 / 11 / toolchain default).
fun Project.alignJvm17() {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
        )
    }
}

subprojects {
    if (state.executed) {
        alignJvm17()
    } else {
        afterEvaluate { alignJvm17() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
