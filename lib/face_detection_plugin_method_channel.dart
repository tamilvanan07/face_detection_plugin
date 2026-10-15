import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'face_detection_plugin_platform_interface.dart';

/// An implementation of [FaceDetectionPluginPlatform] that uses method channels.
class MethodChannelFaceDetectionPlugin extends FaceDetectionPluginPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('face_detection_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  /// Sends the two model asset paths to the native side so it can load them
  /// from the host app's asset bundle instead of the plugin's own assets.
  @override
  Future<void> initialize({
    required String blazeFaceModelPath,
    required String facenetModelPath,
  }) async {
    try {
      await methodChannel.invokeMethod<void>('initialize', {
        'blazeFaceModelPath': blazeFaceModelPath,
        'facenetModelPath': facenetModelPath,
      });
    } on PlatformException catch (e) {
      debugPrint('FaceDetectionPlugin initialize error: ${e.message}');
      rethrow;
    }
  }

  /// Extracts 512-dimensional face embedding float array from an image path/URI
  Future<List<double>?> extractFaceEmbedding(String imagePath) async {
    try {
      final List<dynamic>? rawEmbedding = await methodChannel
          .invokeMethod<List<dynamic>>('extractFaceEmbedding', {
            'imagePath': imagePath,
          });
      if (rawEmbedding != null) {
        return rawEmbedding.map((e) => (e as num).toDouble()).toList();
      }
    } on PlatformException catch (e) {
      debugPrint('Error extracting face embedding: ${e.message}');
    }
    return null;
  }

  /// Detects face bounding box from an image path/URI
  Future<Map<String, dynamic>?> detectFaces(String imagePath) async {
    try {
      final Map<dynamic, dynamic>? result = await methodChannel
          .invokeMethod<Map<dynamic, dynamic>>('detectFaces', {
            'imagePath': imagePath,
          });
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException catch (e) {
      debugPrint('Error detecting faces: ${e.message}');
    }
    return null;
  }

  /// Set or clear the method call listener for real-time camera callbacks.
  /// Pass null to stop receiving callbacks (call from dispose).
  void setNativeCallbackHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    methodChannel.setMethodCallHandler(handler);
  }
}
