# Face Detection Plugin Example App

This example app demonstrates how to use `face_detection_plugin` alongside an **ObjectBox Vector Database** for on-device face registration and real-time face identification.

## Key Features

- **Multi-Angle Face Registration**: Captures face embeddings across multiple poses (center, tilt, etc.) and indexes them in an on-device vector database.
- **Real-Time Face Recognition**: Continuous camera preview with native face detection overlay and 512-dimensional vector similarity matching against registered persons.
- **Offline & On-Device**: Face detection, embedding extraction (FaceNet 512), and vector search run entirely locally on the device.

## Prerequisites

1. **Android Device**: A physical Android device with camera hardware (Android 5.0 / API 21+).
2. **Model Assets**: Ensure the required TensorFlow Lite model files are placed under `assets/`:
   - `assets/blaze_face_short_range.tflite`
   - `assets/facenet_512.tflite`
   These are referenced in `pubspec.yaml` and loaded during app initialization.

## Getting Started

1. Navigate to the example directory:
   ```bash
   cd example
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Generate ObjectBox code (if modified):
   ```bash
   dart run build_runner build
   ```

4. Run the app on your Android device:
   ```bash
   flutter run
   ```

## Architecture

- **`lib/main.dart`**: Initializes `FaceDetectionPlugin` with model assets and opens the global `ObjectBoxVectorStore`.
- **`lib/screens/home_screen.dart`**: Dashboard showing registered people with actions to register new faces or run live identification.
- **`lib/screens/register_camera_screen.dart`**: Interactive camera session guiding the user through capturing facial angles.
- **`lib/screens/register_details_screen.dart`**: Form to attach user metadata (name, age) and commit embeddings into ObjectBox.
- **`lib/screens/identify_camera_screen.dart`**: Live detection screen displaying matching person names and similarity scores in real-time.
- **`lib/bloc/identify_bloc.dart`**: State management for live stream callbacks and nearest-neighbor vector queries.

