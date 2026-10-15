//package com.example.rectModel
//
//class RectangleOverlay(
//    private val overlay: GraphicOverlay<*>,
//    private val face : Face,
//    private val rect : Rect
//) : GraphicOverlay.Graphic(overlay) {
//
//    private val boxPaint : Paint = Paint()
//
//    init {
//        boxPaint.color = Color.GREEN
//        boxPaint.style = Paint.Style.STROKE
//        boxPaint.strokeWidth = 3.0f
//    }
//
//    override fun draw(canvas: Canvas) {
//        val rect = CameraUtils.calculateRect(
//            overlay,
//            rect.height().toFloat(),
//            rect.width().toFloat(),
//            face.boundingBox
//        )
//        canvas.drawRect(rect, boxPaint)
//    }
//
//}