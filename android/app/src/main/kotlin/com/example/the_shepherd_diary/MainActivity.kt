package com.example.the_shepherd_diary

import android.graphics.BitmapFactory
import android.content.Intent
import android.provider.CalendarContract
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "shepherd/calendar")
            .setMethodCallHandler { call, result ->
                if (call.method != "addEvent") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val start = call.argument<Number>("start")?.toLong()
                val end = call.argument<Number>("end")?.toLong()
                if (start == null || end == null) {
                    result.error("date", "Missing event dates", null)
                    return@setMethodCallHandler
                }
                val intent = Intent(Intent.ACTION_INSERT, CalendarContract.Events.CONTENT_URI)
                    .putExtra(CalendarContract.Events.TITLE, call.argument<String>("title"))
                    .putExtra(CalendarContract.Events.EVENT_LOCATION, call.argument<String>("location"))
                    .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start)
                    .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end)
                try {
                    startActivity(intent)
                    result.success(null)
                } catch (error: android.content.ActivityNotFoundException) {
                    result.error("calendar", "No calendar app available", null)
                }
            }
        MethodChannel(engine.dartExecutor.binaryMessenger, "shepherd/liturgy_ocr")
            .setMethodCallHandler { call, result ->
                val bytes = call.arguments as? ByteArray
                if (call.method != "read") {
                    result.notImplemented()
                } else if (bytes == null) {
                    result.error("image", "Missing image", null)
                } else {
                    Thread {
                        val reading = runCatching { recognize(bytes) }
                        runOnUiThread {
                            reading.fold(
                                { result.success(it) },
                                { result.error("ocr", it.message, null) }
                            )
                        }
                    }.start()
                }
            }
    }

    @Synchronized
    private fun recognize(bytes: ByteArray): List<List<String>> {
        val directory = File(filesDir, "tessdata").apply { mkdirs() }
        val model = File(directory, "ara.traineddata")
        if (!model.exists()) {
            val temp = File.createTempFile("ara", ".tmp", directory)
            try {
                assets.open("tessdata/ara.traineddata").use { source ->
                    temp.outputStream().use { source.copyTo(it) }
                }
                check(temp.renameTo(model))
            } finally {
                temp.delete()
            }
        }
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        options.inJustDecodeBounds = false
        options.inSampleSize = 1
        while (maxOf(options.outWidth, options.outHeight) / options.inSampleSize > 3000) {
            options.inSampleSize *= 2
        }
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
            ?: error("Invalid image")
        val api = TessBaseAPI()
        try {
            check(api.init(filesDir.absolutePath, "ara"))
            val xs = gridLines(bitmap.width, bitmap.height) { x, y ->
                bitmap.getPixel(x, y)
            }
            val ys = gridLines(bitmap.height, bitmap.width) { y, x ->
                bitmap.getPixel(x, y)
            }
            check(xs.size == 8 && ys.size >= 4) { "Unrecognized table layout" }
            api.setPageSegMode(TessBaseAPI.PageSegMode.PSM_SINGLE_LINE)
            api.setImage(bitmap)
            return (1 until ys.lastIndex).map { row ->
                (0 until xs.lastIndex).map { column ->
                    val left = xs[column] + 3
                    val top = ys[row] + 3
                    api.setRectangle(left, top, xs[column + 1] - left - 3, ys[row + 1] - top - 3)
                    api.getUTF8Text().trim()
                }
            }
        } finally {
            api.recycle()
            bitmap.recycle()
        }
    }

    private fun gridLines(count: Int, length: Int, pixel: (Int, Int) -> Int): List<Int> {
        val lines = mutableListOf<Int>()
        var start = -1
        for (position in 0..count) {
            val dark = position < count && (0 until length step 2).count { other ->
                val color = pixel(position, other)
                ((color shr 16) and 255) < 100 &&
                    ((color shr 8) and 255) < 100 && (color and 255) < 100
            } > length * 0.29
            if (dark && start < 0) start = position
            if (!dark && start >= 0) {
                lines.add((start + position - 1) / 2)
                start = -1
            }
        }
        return lines
    }
}


