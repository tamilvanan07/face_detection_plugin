import 'package:face_detection_plugin/face_detection_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'db/objectbox_store.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize the plugin with the model assets bundled by this example app.
  // The asset paths must match what is declared in example/pubspec.yaml.
  await FaceDetectionPlugin().initialize(
    blazeFaceModelPath: 'assets/blaze_face_short_range.tflite',
    facenetModelPath: 'assets/facenet_512.tflite',
  );

  // Open ObjectBox once for the lifetime of the app.
  // Every screen receives this instance — no screen opens its own store.
  final store = await ObjectBoxVectorStore.create();

  runApp(FaceDetectionApp(store: store));
}

class FaceDetectionApp extends StatelessWidget {
  const FaceDetectionApp({super.key, required this.store});

  final ObjectBoxVectorStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Detection Plugin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: HomeScreen(store: store),
    );
  }
}
