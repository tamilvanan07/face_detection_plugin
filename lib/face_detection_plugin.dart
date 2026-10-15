import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'face_detection_plugin_method_channel.dart';
import 'face_detection_plugin_platform_interface.dart';

/// The primary interface for the Face Detection plugin on Android.
///
/// Provides methods for initializing TensorFlow Lite models, extracting
/// 512-dimensional face embeddings, detecting faces, and receiving
/// real-time camera callbacks.
class FaceDetectionPlugin {
  // Singleton — all screens share one instance so there is only ever one
  // active method-channel handler and initialize() is called exactly once.
  static final FaceDetectionPlugin _instance = FaceDetectionPlugin._internal();

  /// Returns the singleton instance of [FaceDetectionPlugin].
  factory FaceDetectionPlugin() => _instance;
  FaceDetectionPlugin._internal();

  final MethodChannelFaceDetectionPlugin _methodChannel =
      MethodChannelFaceDetectionPlugin();

  /// Returns the current platform version string.
  Future<String?> getPlatformVersion() {
    return FaceDetectionPluginPlatform.instance.getPlatformVersion();
  }

  /// Initializes the plugin with the TFLite model asset paths declared in the
  /// **host app's** pubspec.yaml.
  ///
  /// Call this once from `main()` before using any detection/embedding APIs.
  ///
  /// ```dart
  /// await FaceDetectionPlugin().initialize(
  ///   blazeFaceModelPath: 'assets/blaze_face_short_range.tflite',
  ///   facenetModelPath:   'assets/facenet_512.tflite',
  /// );
  /// ```
  Future<void> initialize({
    required String blazeFaceModelPath,
    required String facenetModelPath,
  }) {
    return FaceDetectionPluginPlatform.instance.initialize(
      blazeFaceModelPath: blazeFaceModelPath,
      facenetModelPath: facenetModelPath,
    );
  }

  /// Extract 512-dim face embedding vector from image path/URI via TensorFlow Lite
  Future<List<double>?> extractFaceEmbedding(String imagePath) {
    return _methodChannel.extractFaceEmbedding(imagePath);
  }

  /// Detect faces from image path/URI
  Future<Map<String, dynamic>?> detectFaces(String imagePath) {
    return _methodChannel.detectFaces(imagePath);
  }

  /// Listen for real-time camera frames and face embedding callbacks from native plugin.
  ///
  /// Only one listener is active at a time — calling this again replaces the
  /// previous one. Call [removeNativeCallbackListener] when your screen disposes.
  void listenToNativeCallbacks({
    required Function(Map<String, dynamic> frameData) onFrameData,
    required Function(List<double> embedding, Map<String, dynamic> boundingBox)
    onEmbeddingExtracted,
  }) {
    _methodChannel.setNativeCallbackHandler((MethodCall call) async {
      switch (call.method) {
        case 'onFrameData':
          if (call.arguments != null) {
            final map = Map<String, dynamic>.from(call.arguments as Map);
            onFrameData(map);
          }
          break;
        case 'onEmbeddingValue':
          if (call.arguments != null) {
            final map = Map<String, dynamic>.from(call.arguments as Map);
            final rawEmbedding = map['embedding'] as List<dynamic>?;
            final boundingBox = map['boundingBox'] != null
                ? Map<String, dynamic>.from(map['boundingBox'] as Map)
                : <String, dynamic>{};

            if (rawEmbedding != null) {
              final embedding = rawEmbedding
                  .map((e) => (e as num).toDouble())
                  .toList();
              onEmbeddingExtracted(embedding, boundingBox);
            }
          }
          break;
      }
    });
  }

  /// Removes the active native callback listener.
  /// Call this from your screen's [State.dispose] to stop receiving callbacks
  /// after the screen is gone.
  void removeNativeCallbackListener() {
    _methodChannel.setNativeCallbackHandler(null);
  }
}

/// A Flutter Widget that embeds the native Android camera view with face detection overlay.
class FaceCameraView extends StatelessWidget {
  /// Creates a [FaceCameraView] widget.
  const FaceCameraView({super.key});

  @override
  Widget build(BuildContext context) {
    const String viewType = 'camera_view';
    final Map<String, dynamic> creationParams = <String, dynamic>{};

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    return Center(
      child: Text(
        '$defaultTargetPlatform is not supported yet for camera view.',
      ),
    );
  }
}
