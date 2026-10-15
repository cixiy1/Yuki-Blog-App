import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── 固定签名 ────────────────────────────────────────────────────────────────
// 参数写在 android/key.properties（已 gitignore，模板见 android/key.properties.example），
// 生成密钥库用 tool/gen_release_keystore.sh。
// 没配置时回退 debug 签名：clone 下来照样能构建，但 debug 密钥每台机器都不同，
// 构建出的包无法覆盖安装已有的正式版 —— 发版必须配固定签名。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun signingProp(key: String): String? =
    keystoreProperties.getProperty(key)?.trim()?.takeIf { it.isNotEmpty() }

val signingStore: File? = signingProp("storeFile")?.let { keystorePropertiesFile.parentFile.resolve(it) }
val signingReady: Boolean = signingProp("storePassword") != null &&
    signingProp("keyPassword") != null &&
    signingProp("keyAlias") != null &&
    signingStore?.exists() == true

android {
    namespace = "com.yiyu14.yuki_blog_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.yiyu14.yuki_blog_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingReady) {
            create("release") {
                keyAlias = signingProp("keyAlias")
                keyPassword = signingProp("keyPassword")
                storeFile = signingStore
                storePassword = signingProp("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // 有固定签名就用固定签名，否则退回 debug（便于本地直接构建）
            signingConfig = if (signingReady) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        // debug 也套同一把密钥：手机上已装过正式版时，flutter run 能直接覆盖安装
        debug {
            if (signingReady) signingConfig = signingConfigs.getByName("release")
        }
        // profile 同理（该构建类型由 Flutter 插件注册，没有就跳过）
        if (signingReady) {
            findByName("profile")?.signingConfig = signingConfigs.getByName("release")
        }
    }
}

if (signingReady) {
    logger.lifecycle("[signing] 使用固定签名密钥：alias=${signingProp("keyAlias")}，keystore=${signingStore?.name}")
} else {
    logger.lifecycle(
        "[signing] ⚠ 未配置固定签名（android/key.properties 缺失或未填全），本次构建回退 debug 密钥，" +
            "产出的包无法覆盖安装已有正式版。配置方法见 android/key.properties.example"
    )
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
