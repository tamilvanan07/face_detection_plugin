package com.tv.face_detection_plugin.TensorFlowModel

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.support.common.TensorOperator
import org.tensorflow.lite.support.image.ImageProcessor
import org.tensorflow.lite.support.image.TensorImage
import org.tensorflow.lite.support.image.ops.ResizeOp
import org.tensorflow.lite.support.tensorbuffer.TensorBuffer
import org.tensorflow.lite.support.tensorbuffer.TensorBufferFloat
import java.io.FileInputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sqrt

class Facenet512(context: Context) {
    private var interpreter: Interpreter? = null
    private val imgSize = 160
    private val embeddingDim = 512

    private val imageTensorProcessor =
        ImageProcessor.Builder()
            .add(ResizeOp(imgSize, imgSize, ResizeOp.ResizeMethod.BILINEAR))
            .add(StandardizeOp())
            .build()

    fun loadModel(context: Context, modelAssetPath: String = "facenet_512.tflite") {
        try {
            val options = Interpreter.Options().apply {
                setUseXNNPACK(false)
            }
            val modelFile = loadModelFile(context, modelAssetPath)
            interpreter = Interpreter(modelFile, options)
            val inputTensor = interpreter?.getInputTensor(0)
            Log.d("TFLITE", "Input Shape: ${inputTensor?.shape().contentToString()}, Type: ${inputTensor?.dataType()}")
        } catch (e: IOException) {
            e.printStackTrace()
            throw RuntimeException("Failed to load FaceNet model: ${e.message}")
        }
    }

    @Throws(IOException::class)
    private fun loadModelFile(context: Context, modelName: String): ByteBuffer {
        val assetFileDescriptor = context.assets.openFd(modelName)
        val inputStream = FileInputStream(assetFileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel
        val startOffset = assetFileDescriptor.startOffset
        val declaredLength = assetFileDescriptor.declaredLength
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
    }

    suspend fun getFaceEmbedding(image: Bitmap): FloatArray =
        withContext(Dispatchers.IO) {
            return@withContext runFaceNet(convertBitmapToBuffer(image))[0]
        }

    private fun runFaceNet(inputs: Any): Array<FloatArray> {
        val faceNetModelOutputs = Array(1) { FloatArray(embeddingDim) }
        interpreter?.run(inputs, faceNetModelOutputs)
        return faceNetModelOutputs
    }

    private fun convertBitmapToBuffer(image: Bitmap): ByteBuffer {
        return imageTensorProcessor.process(TensorImage.fromBitmap(image)).buffer
    }

    fun resizeBitmap(bitmap: Bitmap, width: Int, height: Int): Bitmap {
        return Bitmap.createScaledBitmap(bitmap, width, height, true)
    }

    fun process(image: Bitmap?): FloatArray {
        val resizedBitmap = resizeBitmap(image ?: return floatArrayOf(), 160, 160)
        val byteBuffer = convertBitmapToByteBuffer(resizedBitmap)
        val outputBuffer = TensorBuffer.createFixedSize(intArrayOf(1, 512), DataType.FLOAT32)
        interpreter?.run(byteBuffer, outputBuffer.buffer)
        return outputBuffer.floatArray
    }

    fun close() {
        interpreter?.close()
    }

    fun convertBitmapToByteBuffer(bitmap: Bitmap): ByteBuffer {
        val inputSize = bitmap.width * bitmap.height * 3
        val byteBuffer = ByteBuffer.allocateDirect(inputSize * 4)
        byteBuffer.order(ByteOrder.nativeOrder())

        val intValues = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(intValues, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)

        for (pixel in intValues) {
            val r = ((pixel shr 16) and 0xFF) / 255.0f
            val g = ((pixel shr 8) and 0xFF) / 255.0f
            val b = (pixel and 0xFF) / 255.0f
            byteBuffer.putFloat(r)
            byteBuffer.putFloat(g)
            byteBuffer.putFloat(b)
        }

        byteBuffer.rewind()
        return byteBuffer
    }

    class StandardizeOp : TensorOperator {
        override fun apply(p0: TensorBuffer?): TensorBuffer {
            val pixels = p0!!.floatArray
            val mean = pixels.average().toFloat()
            var std = sqrt(pixels.map { pi -> (pi - mean).pow(2) }.sum() / pixels.size.toFloat())
            std = max(std, 1f / sqrt(pixels.size.toFloat()))
            for (i in pixels.indices) {
                pixels[i] = (pixels[i] - mean) / std
            }
            val output = TensorBufferFloat.createFixedSize(p0.shape, DataType.FLOAT32)
            output.loadArray(pixels)
            return output
        }
    }
}