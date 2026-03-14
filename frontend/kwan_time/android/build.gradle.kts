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
subprojects {
    project.evaluationDependsOn(":app")
}
fun Project.applyLegacyNamespaceFallback() {
    val androidExtension = extensions.findByName("android") ?: return
    val getNamespace = androidExtension.javaClass.methods.firstOrNull {
        it.name == "getNamespace" && it.parameterCount == 0
    } ?: return
    val currentNamespace = getNamespace.invoke(androidExtension) as String?
    if (!currentNamespace.isNullOrBlank()) {
        return
    }

    val manifestFile = file("src/main/AndroidManifest.xml")
    if (!manifestFile.exists()) {
        return
    }

    val packageName = Regex("""package="([^"]+)"""")
        .find(manifestFile.readText())
        ?.groupValues
        ?.getOrNull(1)
        ?: return
    val setNamespace = androidExtension.javaClass.methods.firstOrNull {
        it.name == "setNamespace" && it.parameterCount == 1
    } ?: return
    setNamespace.invoke(androidExtension, packageName)
}

subprojects {
    if (state.executed) {
        applyLegacyNamespaceFallback()
    } else {
        afterEvaluate {
            applyLegacyNamespaceFallback()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
