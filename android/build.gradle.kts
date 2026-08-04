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
// Some plugin subprojects (e.g. home_widget) default to JVM target 1.8 while
// inlining JVM 11+ bytecode from transitive deps, which breaks the release
// Kotlin compile. Force every subproject's Java + Kotlin toolchain to 17 to
// match the app module and keep the Java/Kotlin targets consistent. This block
// is registered before evaluationDependsOn(":app") so the reactions attach
// before AGP finalizes each module's DSL.
subprojects {
    // afterEvaluate so this runs after each plugin's own build script, which
    // otherwise pins Java compatibility back down to 1.8 (e.g. home_widget).
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
    }
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java)
        .configureEach {
            compilerOptions.jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            )
        }

    // home_widget declares androidx.glance:glance-appwidget:1.+, a dynamic
    // range that now resolves to 1.3.0-alpha02 — an alpha requiring AGP 9.1 /
    // compileSdk 37. Pin glance back to the last stable release compatible with
    // the current AGP 8.11 / compileSdk 36 toolchain.
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.glance") {
                useVersion("1.1.1")
                because("glance 1.3.0-alpha02 requires AGP 9.1 / compileSdk 37")
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
