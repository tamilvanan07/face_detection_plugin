import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'face_detection_plugin_method_channel.dart';

abstract class FaceDetectionPluginPlatform extends PlatformInterface {
  /// Constructs a FaceDetectionPluginPlatform.
  FaceDetectionPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static FaceDetectionPluginPlatform _instance =
      MethodChannelFaceDetectionPlugin();

  /// The default instance of [FaceDetectionPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelFaceDetectionPlugin].
  static FaceDetectionPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FaceDetectionPluginPlatform] when
  /// they register themselves.
  static set instance(FaceDetectionPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the current platform version string.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Initializes the plugin with the asset paths for the two TFLite models.
  ///
  /// [blazeFaceModelPath] — asset path to the BlazeFace short-range model,
  ///   e.g. `"assets/blaze_face_short_range.tflite"`.
  /// [facenetModelPath]  — asset path to the FaceNet 512-dim embedding model,
  ///   e.g. `"assets/facenet_512.tflite"`.
  Future<void> initialize({
    required String blazeFaceModelPath,
    required String facenetModelPath,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }
}
