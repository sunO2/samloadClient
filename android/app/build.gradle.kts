plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.firmware_client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.firmware_client"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ndk {
          //  abiFilters.add("arm64-v8a") // 只打包 armeabi-v7a 和 arm64-v8a 架构的库
            // abiFilters.add("arm64-v8a") // Kotlin DSL 更推荐的写法
        //}
    }

    //splits {
     //   abi {
            //enable = true
      //      reset() // 清除默认包含的 ABI
      //      include("arm64-v8a") // 明确只包含 arm64-v8a
      //      isUniversalApk = false // 不生成包含所有 ABI 的通用 APK
      //  }
    //}

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    sourceSets {
        getByName("main") {
            // 指定 jniLibs 目录，这里假设你的 .so 文件放在 app/libs/ 目录下
            // 路径可以是相对路径，也可以是绝对路径
            // 注意：如果你使用了默认的 jniLibs 目录，通常不需要这一行
            jniLibs.srcDirs("src/main/jniLibs") // 示例：指向自定义的 libs 目录
            // 也可以添加多个目录
            // jniLibs.srcDirs("src/main/libs", "path/to/another/libs")
        }
    }
}

flutter {
    source = "../.."
}
