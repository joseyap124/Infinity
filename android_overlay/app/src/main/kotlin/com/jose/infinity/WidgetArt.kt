package com.jose.infinity

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF

/**
 * Cincin sisa jatah dengan maskot di tengahnya untuk widget (v5.0).
 * Digambar di sini karena RemoteViews hanya menerima bitmap atau view bawaan.
 * Suasana maskot dan persen cincin dikirim dari main.dart (w_mood, w_ring).
 */
object WidgetArt {
    private fun mascotRes(mood: String): Int = when (mood) {
        "happy" -> R.drawable.w_mascot_happy
        "warn" -> R.drawable.w_mascot_warn
        "danger" -> R.drawable.w_mascot_danger
        "over" -> R.drawable.w_mascot_over
        "sleepy" -> R.drawable.w_mascot_sleepy
        else -> R.drawable.w_mascot_ok
    }

    private fun ringColor(mood: String): Int = when (mood) {
        "happy", "ok" -> Color.parseColor("#FF2FBF71")
        "warn" -> Color.parseColor("#FFE8A317")
        "danger", "over" -> Color.parseColor("#FFE5484D")
        else -> Color.parseColor("#FF9AA3AE")
    }

    fun ring(context: Context, mood: String, percent: Int, size: Int = 256): Bitmap {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val stroke = size * 0.10f
        val half = stroke / 2f
        val rect = RectF(half, half, size - half, size - half)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        paint.color = Color.parseColor("#33FFFFFF")
        c.drawArc(rect, 0f, 360f, false, paint)
        val p = percent.coerceIn(0, 100)
        if (p > 0) {
            paint.color = ringColor(mood)
            c.drawArc(rect, -90f, 360f * p / 100f, false, paint)
        }
        val inset = stroke + size * 0.03f
        val disc = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        c.drawCircle(size / 2f, size / 2f, size / 2f - inset, disc)
        val m = BitmapFactory.decodeResource(context.resources, mascotRes(mood))
        if (m != null) {
            val inner = size - inset * 2f
            val w = inner * 0.88f
            val h = w * m.height / m.width
            val left = (size - w) / 2f
            val top = (size - h) / 2f
            c.drawBitmap(m, null, RectF(left, top, left + w, top + h), Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
        }
        return bmp
    }
}
