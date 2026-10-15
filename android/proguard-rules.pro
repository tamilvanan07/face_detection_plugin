# ML Kit / Vision
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# TensorFlow Lite
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }

# MediaPipe Vision Tasks
-keep class com.google.mediapipe.** { *; }
-keep class com.google.mediapipe.tasks.** { *; }
-keep class com.google.mediapipe.framework.** { *; }

# Prevent removal of native methods & annotations
-keepattributes *Annotation*
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
-keepclasseswithmembers class * {
    native <methods>;
}

# Ignore compiler-only annotation classes
-dontwarn javax.lang.**
-dontwarn com.squareup.javapoet.**
-dontwarn com.google.auto.value.**

# Common model serialization protection
-keep class * implements java.io.Serializable {
    *;
}