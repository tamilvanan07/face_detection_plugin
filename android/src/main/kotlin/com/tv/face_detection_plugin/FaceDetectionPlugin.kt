package com.tv.face_detection_plugin

import android.app.Activity
import android.content.Context
import android.graphics.SurfaceTexture
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.tv.face_detection_plugin.TensorFlowModel.Facenet512
import com.tv.face_detection_plugin.TensorFlowModel.MediapipeFaceDetector
import com.tv.face_detection_plugin.cameraView.YourCameraViewFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/** FaceDetectionPlugin */
class FaceDetectionPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    companion object {
        const val TAG = "FacePlugin"
    }

    private var channelPrimary: MethodChannel? = null
    private var channelSecondary: MethodChannel? = null
    private var surfaceTexture: SurfaceTexture? = null
    var context: Context? = null
        private set
    var activity: Activity? = null
        private set

    // Exposed so CameraView can reuse the already-loaded models without reloading.
    var mediaDetector: MediapipeFaceDetector? = null
        private set
    var facenetModel: Facenet512? = null
        private set
    private val mainHandler = Handler(Looper.getMainLooper())

    // Holds the Flutter asset lookup helper so initialize() can resolve asset paths.
    private var flutterAssets: FlutterPlugin.FlutterAssets? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine: plugin initializing")
        context = flutterPluginBinding.applicationContext
        flutterAssets = flutterPluginBinding.flutterAssets

        channelPrimary = MethodChannel(flutterPluginBinding.binaryMessenger, "face_detection_plugin")
        channelPrimary?.setMethodCallHandler(this)

        channelSecondary = MethodChannel(flutterPluginBinding.binaryMessenger, "tensorflow_objectbox_plugin")
        channelSecondary?.setMethodCallHandler(this)

        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "camera_view",
            YourCameraViewFactory(flutterPluginBinding.applicationContext, flutterPluginBinding.binaryMessenger, this)
        )
        // Models are NOT loaded here anymore.
        // They are loaded lazily when the Dart side calls initialize() with asset paths.
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onDetachedFromEngine: cleaning up")
        channelPrimary?.setMethodCallHandler(null)
        channelPrimary = null
        channelSecondary?.setMethodCallHandler(null)
        channelSecondary = null
        facenetModel?.close()
        facenetModel = null
        flutterAssets = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "onAttachedToActivity: ${binding.activity.javaClass.simpleName}")
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges")
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges")
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity")
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "onMethodCall: ${call.method}")
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "initialize" -> {
                val blazeFaceAssetPath = call.argument<String>("blazeFaceModelPath")
                val facenetAssetPath   = call.argument<String>("facenetModelPath")

                if (blazeFaceAssetPath == null || facenetAssetPath == null) {
                    result.error("INVALID_ARGUMENT", "Both blazeFaceModelPath and facenetModelPath are required", null)
                    return
                }

                val ctx = context
                val assets = flutterAssets
                if (ctx == null || assets == null) {
                    result.error("NOT_READY", "Plugin context not available", null)
                    return
                }

                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        // FlutterAssets resolves the Dart asset key to the actual path
                        // inside the APK asset bundle (e.g. "flutter_assets/assets/model.tflite").
                        val resolvedBlaze   = assets.getAssetFilePathByName(blazeFaceAssetPath)
                        val resolvedFacenet = assets.getAssetFilePathByName(facenetAssetPath)
                        Log.d(TAG, "initialize: blazeFace=$resolvedBlaze  facenet=$resolvedFacenet")

                        // Pass the resolved paths so each model opens via AssetManager.
                        mediaDetector = MediapipeFaceDetector(ctx, resolvedBlaze)
                        Log.d(TAG, "initialize: MediaPipe detector ready")

                        facenetModel = Facenet512(ctx).apply { loadModel(ctx, resolvedFacenet) }
                        Log.d(TAG, "initialize: FaceNet model ready")

                        withContext(Dispatchers.Main) { result.success(null) }
                    } catch (e: Exception) {
                        Log.e(TAG, "initialize: failed", e)
                        withContext(Dispatchers.Main) {
                            result.error("INIT_FAILED", e.localizedMessage ?: "Initialization error", null)
                        }
                    }
                }
            }
            "getFaceEmbedding", "extractFaceEmbedding" -> {
                val imagePath = call.argument<String>("imagePath")
                val imageUriStr = call.argument<String>("imageUri")

                val targetUri: Uri? = when {
                    imageUriStr != null -> Uri.parse(imageUriStr)
                    imagePath != null -> Uri.fromFile(File(imagePath))
                    else -> null
                }

                if (targetUri == null) {
                    Log.e(TAG, "extractFaceEmbedding: missing imagePath and imageUri")
                    result.error("INVALID_ARGUMENT", "Provide imagePath or imageUri", null)
                    return
                }

                Log.d(TAG, "extractFaceEmbedding: processing uri=$targetUri")
                extractFaceEmbeddingFromUri(targetUri, result)
            }
            "detectFaces" -> {
                val imagePath = call.argument<String>("imagePath")
                val imageUriStr = call.argument<String>("imageUri")

                val targetUri: Uri? = when {
                    imageUriStr != null -> Uri.parse(imageUriStr)
                    imagePath != null -> Uri.fromFile(File(imagePath))
                    else -> null
                }

                if (targetUri == null) {
                    Log.e(TAG, "detectFaces: missing imagePath and imageUri")
                    result.error("INVALID_ARGUMENT", "Provide imagePath or imageUri", null)
                    return
                }

                Log.d(TAG, "detectFaces: processing uri=$targetUri")
                detectFacesFromUri(targetUri, result)
            }
            else -> {
                Log.w(TAG, "onMethodCall: unhandled method '${call.method}'")
                result.notImplemented()
            }
        }
    }

    private fun extractFaceEmbeddingFromUri(uri: Uri, result: Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d(TAG, "extractFaceEmbeddingFromUri: detecting face in image")
                val croppedResult = mediaDetector?.getCroppedFace(uri)
                if (croppedResult != null && croppedResult.isSuccess) {
                    val croppedBitmap = croppedResult.getOrNull()
                    if (croppedBitmap != null) {
                        Log.d(TAG, "extractFaceEmbeddingFromUri: face cropped ${croppedBitmap.width}x${croppedBitmap.height}, running FaceNet")
                        val embedding = facenetModel?.getFaceEmbedding(croppedBitmap)
                        if (embedding != null) {
                            Log.d(TAG, "extractFaceEmbeddingFromUri: embedding generated dims=${embedding.size}")
                            withContext(Dispatchers.Main) { result.success(embedding.toList()) }
                            return@launch
                        } else {
                            Log.e(TAG, "extractFaceEmbeddingFromUri: FaceNet returned null embedding")
                        }
                    } else {
                        Log.e(TAG, "extractFaceEmbeddingFromUri: cropped bitmap is null")
                    }
                } else {
                    Log.e(TAG, "extractFaceEmbeddingFromUri: face detection failed – ${croppedResult?.exceptionOrNull()?.message}")
                }
                withContext(Dispatchers.Main) {
                    result.error("EMBEDDING_FAILED", "Could not detect face or generate embedding", null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "extractFaceEmbeddingFromUri: exception", e)
                withContext(Dispatchers.Main) {
                    result.error("ERROR", e.localizedMessage ?: "Extraction error", null)
                }
            }
        }
    }

    private fun detectFacesFromUri(uri: Uri, result: Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d(TAG, "detectFacesFromUri: running detection")
                val croppedResult = mediaDetector?.getCroppedFace(uri)
                if (croppedResult != null && croppedResult.isSuccess) {
                    val croppedBitmap = croppedResult.getOrNull()
                    if (croppedBitmap != null) {
                        Log.d(TAG, "detectFacesFromUri: face found ${croppedBitmap.width}x${croppedBitmap.height}")
                        val faceData = mapOf(
                            "width" to croppedBitmap.width,
                            "height" to croppedBitmap.height,
                            "detected" to true
                        )
                        withContext(Dispatchers.Main) { result.success(faceData) }
                        return@launch
                    }
                } else {
                    Log.w(TAG, "detectFacesFromUri: no face detected – ${croppedResult?.exceptionOrNull()?.message}")
                }
                withContext(Dispatchers.Main) { result.success(mapOf("detected" to false)) }
            } catch (e: Exception) {
                Log.e(TAG, "detectFacesFromUri: exception", e)
                withContext(Dispatchers.Main) {
                    result.error("ERROR", e.localizedMessage ?: "Detection error", null)
                }
            }
        }
    }

    fun setSurfaceTexture(surface: SurfaceTexture) {
        Log.d(TAG, "setSurfaceTexture: surface set")
        this.surfaceTexture = surface
    }

    fun sendFrameData(data: Map<String, Any?>) {
        val hasEmbedding = data["embedding"] != null
        Log.v(TAG, "sendFrameData: hasEmbedding=$hasEmbedding bbox=${data["left"]},${data["top"]},${data["right"]},${data["bottom"]}")
        mainHandler.post {
            channelPrimary?.invokeMethod("onFrameData", data)
            channelSecondary?.invokeMethod("onFrameData", data)
        }
    }

    fun sendEmbeddingValue(data: Any?) {
        Log.d(TAG, "sendEmbeddingValue: dispatching embedding to Flutter")
        mainHandler.post {
            channelPrimary?.invokeMethod("onEmbeddingValue", data)
            channelSecondary?.invokeMethod("onEmbeddingValue", data)
        }
    }

    fun sendFaceDetected(data: Map<String, Any?>) {
        Log.d(TAG, "sendFaceDetected: ${data["detected"]}")
        mainHandler.post {
            channelPrimary?.invokeMethod("onFaceDetected", data)
            channelSecondary?.invokeMethod("onFaceDetected", data)
        }
    }
}
