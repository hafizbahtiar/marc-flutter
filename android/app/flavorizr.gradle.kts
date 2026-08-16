import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("flavor-type")

    productFlavors {
        create("staging") {
            dimension = "flavor-type"
            applicationId = "com.hafizbahtiar.marc.staging"
            resValue(type = "string", name = "app_name", value = "Marc Staging")
        }
        create("prod") {
            dimension = "flavor-type"
            applicationId = "com.hafizbahtiar.marc"
            resValue(type = "string", name = "app_name", value = "Marc")
        }
    }

    buildFeatures.resValues = true
}