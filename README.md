# face_detection_plugin

A Flutter plugin for high-performance native Face Detection and TensorFlow Lite Face Embedding extraction.

[![pub package](https://img.shields.io/pub/v/face_detection_plugin.svg)](https://pub.dev/packages/face_detection_plugin)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- 👤 **Native Face Detection**: High-performance face detection backed by native platform implementations.
- 🧬 **TensorFlow Lite Face Embeddings**: Extract 512-dimensional face embedding vectors for facial recognition and similarity matching.
- 📹 **Live Camera View Widget**: `FaceCameraView` widget to embed real-time camera feeds with face detection overlays.
- ⚡ **Asynchronous Callbacks**: Listen to real-time frame data and embedding updates using continuous callback streams.
- 📱 **Platform Support**: Native Android support (CameraX & TensorFlow Lite).

---

## Getting Started

### 1. Add Dependency

Add `face_detection_plugin` to your `pubspec.yaml`:

```yaml
dependencies:
  face_detection_plugin: ^0.0.2
```

Or run:

```bash
flutter pub add face_detection_plugin
```

### 2. Platform Setup (Android)

Ensure your `android/app/build.gradle` has `minSdkVersion` set to 21 or higher:

```groovy
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

Add camera permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
```

### 3. Include Model Assets

In your host application's `pubspec.yaml`, include your TensorFlow Lite model assets:

```yaml
flutter:
  assets:
    - assets/blaze_face_short_range.tflite
    - assets/facenet_512.tflite
```

---

## Usage

### Initialize the Plugin

Initialize the plugin once (e.g. in `main()` or screen initialization) with your model asset paths:

```dart
import 'package:face_detection_plugin/face_detection_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FaceDetectionPlugin().initialize(
    blazeFaceModelPath: 'assets/blaze_face_short_range.tflite',
    facenetModelPath: 'assets/facenet_512.tflite',
  );

  runApp(const MyApp());
}
```

### Display Camera View

Use `FaceCameraView` to render the native camera preview:

```dart
import 'package:flutter/material.dart';
import 'package:face_detection_plugin/face_detection_plugin.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: FaceCameraView(),
    );
  }
}
```

### Listen for Real-Time Native Callbacks

Subscribe to frame data and face embedding updates:

```dart
final plugin = FaceDetectionPlugin();

plugin.listenToNativeCallbacks(
  onFrameData: (Map<String, dynamic> frameData) {
    // Process frame metadata (e.g., width, height, face counts)
  },
  onEmbeddingExtracted: (List<double> embedding, Map<String, dynamic> boundingBox) {
    // Received 512-dim embedding vector and bounding box coordinates
    print('Embedding length: ${embedding.length}');
    print('Bounding box: $boundingBox');
  },
);
```

To clean up when your widget is disposed:

```dart
@override
void dispose() {
  FaceDetectionPlugin().removeNativeCallbackListener();
  super.dispose();
}
```

### Detect Faces from an Image File

```dart
final result = await FaceDetectionPlugin().detectFaces('/path/to/image.jpg');
```

### Extract Face Embedding from an Image File

```dart
final embedding = await FaceDetectionPlugin().extractFaceEmbedding('/path/to/image.jpg');
if (embedding != null) {
  print('Face vector: ${embedding.take(5)}...');
}
```

---

## Example

For a complete working example, check out the [`example`](https://github.com/tamilvanan/face_detection_plugin/tree/main/example) directory in the repository.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
