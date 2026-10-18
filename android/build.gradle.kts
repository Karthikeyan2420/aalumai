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

        // AGP defaults a library's Java target to 1.8 while the Kotlin plugin
        // defaults to the running toolchain (17); AGP 8 fails the build on that
        // mismatch. Align libraries that never configure their own options.
        val script = listOf(
            projectDir.resolve("build.gradle"),
            projectDir.resolve("build.gradle.kts"),
        ).firstOrNull { it.exists() }?.readText().orEmpty()
        if (!script.contains("compileOptions") && !script.contains("sourceCompatibility")) {
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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
