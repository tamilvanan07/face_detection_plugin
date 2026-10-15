package com.tv.face_detection_plugin.tensor_flow_project

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.view.View

class FaceOverlayView(context: Context) : View(context) {
    private val paint = Paint().apply {
        color = Color.GREEN
        style = Paint.Style.STROKE
        strokeWidth = 5f
    }

    private var faceBoundingBox: RectF? = null

    fun setFaceBoundingBox(boundingBox: Rect) {
        faceBoundingBox = RectF(
            boundingBox.left.toFloat(),
            boundingBox.top.toFloat(),
            boundingBox.right.toFloat(),
            boundingBox.bottom.toFloat()
        )
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        faceBoundingBox?.let { canvas.drawRect(it, paint) }
    }
}