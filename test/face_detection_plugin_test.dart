import 'package:flutter_test/flutter_test.dart';
import 'package:face_detection_plugin/face_detection_plugin.dart';
import 'package:face_detection_plugin/face_detection_plugin_platform_interface.dart';
import 'package:face_detection_plugin/face_detection_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFaceDetectionPluginPlatform
    with MockPlatformInterfaceMixin
    implements FaceDetectionPluginPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> initialize({
    required String blazeFaceModelPath,
    required String facenetModelPath,
  }) =>
      Future.value();
}

void main() {
  final FaceDetectionPluginPlatform initialPlatform = FaceDetectionPluginPlatform.instance;

  test('$MethodChannelFaceDetectionPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFaceDetectionPlugin>());
  });

  test('getPlatformVersion', () async {
    FaceDetectionPlugin faceDetectionPlugin = FaceDetectionPlugin();
    MockFaceDetectionPluginPlatform fakePlatform = MockFaceDetectionPluginPlatform();
    FaceDetectionPluginPlatform.instance = fakePlatform;

    expect(await faceDetectionPlugin.getPlatformVersion(), '42');
  });
}
