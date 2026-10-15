package com.tv.face_detection_plugin.cameraView

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Bitmap
import android.graphics.Rect
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.camera.core.AspectRatio
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.common.util.concurrent.ListenableFuture
import com.tv.face_detection_plugin.FaceDetectionPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.concurrent.Executors

// ── Factory ────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalGetImage::class)
class YourCameraViewFactory(
    private val activity: Context,
    private val messenger: BinaryMessenger,
    private val plugin: FaceDetectionPlugin,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, id: Int, creationParams: Any?): PlatformView {
        return CameraPlatformView(activity, messenger, plugin)
    }
}

// ── Data ───────────────────────────────────────────────────────────────────────

data class FaceDetectionResult(
    val boundingBox: Rect,
    val embedding: FloatArray? = null,
)

// ── Platform view ──────────────────────────────────────────────────────────────

@SuppressLint("ViewConstructor")
@OptIn(ExperimentalGetImage::class)
class CameraPlatformView(
    private val context: Context,
    val messenger: BinaryMessenger,
    private val plugin: FaceDetectionPlugin,
) : PlatformView {

    // Root container — Flutter's AndroidView renders this
    private val container: FrameLayout = FrameLayout(context)

    // CameraX PreviewView — handles its own Surface lifecycle correctly
    private val previewView: PreviewView = PreviewView(context).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )
        // FILL_CENTER keeps the aspect ratio and fills the view
        scaleType = PreviewView.ScaleType.FILL_CENTER
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    }

    private var cameraProvider: ProcessCameraProvider? = null

    private var isProcessing = false
    private var isDetectionPaused = false

    init {
        container.addView(previewView)
        // Models are accessed via plugin.mediaDetector / plugin.facenetModel at frame
        // processing time — not cached here — so they're always available even if
        // initialize() completes after the view is constructed.
        startCamera()
    }

    // ── Camera startup ─────────────────────────────────────────────────────────

    private fun startCamera() {
        val activity = getActivity(context)
        if (activity == null || activity.isFinishing || activity.isDestroyed) {
            Log.e(FaceDetectionPlugin.TAG, "CameraView: activity unavailable, cannot start camera")
            return
        }
        if (activity !is LifecycleOwner) {
            Log.e(FaceDetectionPlugin.TAG, "CameraView: activity is not a LifecycleOwner")
            return
        }

        val future: ListenableFuture<ProcessCameraProvider> =
            ProcessCameraProvider.getInstance(activity)

        future.addListener({
            try {
                cameraProvider = future.get()
                Log.d(FaceDetectionPlugin.TAG, "CameraView: ProcessCameraProvider ready")

                // Preview — surfaceProvider comes straight from PreviewView
                val preview = Preview.Builder().build().also {
                    it.surfaceProvider = previewView.surfaceProvider
                }

                // Image analysis for face detection + embedding
                val analysis = ImageAnalysis.Builder()
                    .setTargetAspectRatio(AspectRatio.RATIO_16_9)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()  // default YUV_420_888 — toBitmap() handles it correctly
                    .also { ia ->
                        ia.setAnalyzer(Executors.newSingleThreadExecutor()) { proxy ->
                            processFrame(proxy)
                        }
                    }

                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(
                    activity as LifecycleOwner,
                    CameraSelector.DEFAULT_FRONT_CAMERA,
                    preview,
                    analysis,
                )
                Log.d(FaceDetectionPlugin.TAG, "CameraView: camera bound to lifecycle")
            } catch (e: Exception) {
                Log.e(FaceDetectionPlugin.TAG, "CameraView: bindToLifecycle failed", e)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    // ── Frame processing ───────────────────────────────────────────────────────

    private fun processFrame(proxy: ImageProxy) {
        if (isProcessing || isDetectionPaused) {
            proxy.close()
            return
        }
        isProcessing = true

        CoroutineScope(Dispatchers.Default).launch {
            try {
                val image = proxy.image
                if (image == null) {
                    Log.e(FaceDetectionPlugin.TAG, "CameraView: imageProxy.image is null — skipping")
                    return@launch
                }

                // toBitmap() correctly handles YUV_420_888 stride/padding and
                // applies the rotation from imageInfo automatically.
                val frameBitmap: Bitmap = proxy.toBitmap()
                Log.v(FaceDetectionPlugin.TAG,
                    "CameraView: frame ${frameBitmap.width}x${frameBitmap.height}")

                // Detect faces
                val detections: List<Pair<Bitmap, Rect>> = try {
                    plugin.mediaDetector?.getAllCroppedFaces(frameBitmap) ?: run {
                        Log.w(FaceDetectionPlugin.TAG, "CameraView: MediaPipe not ready yet")
                        emptyList()
                    }
                } catch (e: Exception) {
                    Log.e(FaceDetectionPlugin.TAG, "CameraView: MediaPipe failed", e)
                    emptyList()
                }

                if (detections.isEmpty()) {
                    Log.v(FaceDetectionPlugin.TAG, "CameraView: no faces in frame")
                } else {
                    Log.d(FaceDetectionPlugin.TAG, "CameraView: ${detections.size} face(s)")
                }

                for ((cropped, box) in detections) {
                    val embedding: FloatArray? = try {
                        plugin.facenetModel?.getFaceEmbedding(cropped)
                    } catch (e: Exception) {
                        Log.e(FaceDetectionPlugin.TAG, "CameraView: FaceNet failed", e)
                        null
                    }

                    val frameData = mapOf(
                        "left" to box.left,
                        "top" to box.top,
                        "width" to box.width(),
                        "height" to box.height(),
                        "bottom" to box.bottom,
                        "right" to box.right,
                        "frameWidth" to frameBitmap.width,
                        "frameHeight" to frameBitmap.height,
                        "embedding" to embedding?.toList(),
                    )
                    plugin.sendFrameData(frameData)

                    if (embedding != null) {
                        plugin.sendEmbeddingValue(
                            mapOf(
                                "embedding" to embedding.toList(),
                                "boundingBox" to mapOf(
                                    "left" to box.left,
                                    "top" to box.top,
                                    "width" to box.width(),
                                    "height" to box.height(),
                                ),
                            ),
                        )
                    }
                }
            } catch (e: Exception) {
                Log.e(FaceDetectionPlugin.TAG, "CameraView: processFrame unhandled exception", e)
            } finally {
                isProcessing = false
                proxy.close()
            }
        }
    }

    // ── PlatformView ───────────────────────────────────────────────────────────

    override fun getView(): View = container

    override fun dispose() {
        Log.d(FaceDetectionPlugin.TAG, "CameraView: dispose")
        isDetectionPaused = true
        try { cameraProvider?.unbindAll() } catch (e: Exception) {
            Log.e(FaceDetectionPlugin.TAG, "CameraView: dispose unbind failed", e)
        }
        // Models are owned by FaceDetectionPlugin — do not close them here.
    }

    override fun onFlutterViewDetached() {
        isDetectionPaused = true
        try { cameraProvider?.unbindAll() } catch (_: Exception) {}
        super.onFlutterViewDetached()
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private fun getActivity(ctx: Context): Activity? {
        plugin.activity?.let { return it }
        var c: Context? = ctx
        while (c is ContextWrapper) {
            if (c is Activity) return c
            c = c.baseContext
        }
        return null
    }
}
