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

// Each Flutter plugin subproject resolves its OWN compileSdk from
// flutter.compileSdkVersion (34 with this Flutter SDK) — raising it only on
// :app does not reach them. file_picker's transitive dependency
// flutter_plugin_android_lifecycle now requires compilation against API 36+, so
// force the plugin modules to 36 here. compileSdk only widens the build-time API
// surface; it does not change minSdk/targetSdk or runtime behaviour.
//
// The evaluationDependsOn(":app") above eagerly evaluates :app, so guard on
// state.executed: :app is already evaluated (and already pinned to 36 in its own
// build.gradle.kts), and calling afterEvaluate on an evaluated project throws.
// The plugin modules are not yet evaluated, so their override is deferred.
subprojects {
    if (!state.executed) {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
                ?.compileSdkVersion(36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
