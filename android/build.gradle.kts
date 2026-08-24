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

// stripe_android's "lintVitalAnalyzeRelease" (an AGP-bundled release-build
// safety check, unrelated to Dart/Flutter analysis) resolves its full lint
// classpath, which pulls in Stripe's card-issuing push-provisioning module
// -> com.google.android.gms:play-services-tapandpay. That artifact lives in
// a restricted Google Maven repo MARC has no access to (issuing/push
// provisioning is unused here - no card-issuing feature in this app), so
// resolution 404s on every release build regardless of app code. Disabling
// just the "vital" lint task (not regular lint/analyze) is the documented
// workaround for this exact stripe_android + AGP interaction.
subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach {
        enabled = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
