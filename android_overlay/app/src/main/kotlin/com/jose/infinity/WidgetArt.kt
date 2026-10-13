package com.jose.infinity

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import java.io.File

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

    /** Maskot pilihan: bawaan (assets Flutter), gambar sendiri, atau klasik. */
    private fun mascot(context: Context, mood: String, skin: String?, path: String?): Bitmap? {
        try {
            if (skin == "owl" || skin == "fox" || skin == "crow") {
                val b = context.assets.open("flutter_assets/assets/mascots/" + skin + "_" + mood + ".png").use {
                    BitmapFactory.decodeStream(it)
                }
                if (b != null) return b
            } else if (skin == "custom" && !path.isNullOrEmpty()) {
                val b = decodeSampled(path, 300)
                if (b != null) return b
            }
        } catch (e: Exception) {
            // kembali ke maskot klasik di bawah
        }
        return BitmapFactory.decodeResource(context.resources, mascotRes(mood))
    }

    /** Baca gambar besar dengan ukuran kecil supaya tidak kehabisan memori. */
    private fun decodeSampled(path: String, target: Int): Bitmap? {
        val bounds = BitmapFactory.Options()
        bounds.inJustDecodeBounds = true
        BitmapFactory.decodeFile(path, bounds)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= target && bounds.outHeight / (sample * 2) >= target) {
            sample *= 2
        }
        val opts = BitmapFactory.Options()
        opts.inSampleSize = sample
        return BitmapFactory.decodeFile(path, opts)
    }

    fun ring(
        context: Context,
        mood: String,
        percent: Int,
        size: Int = 256,
        theme: WidgetTheme? = null,
        skin: String? = null,
        skinPath: String? = null,
    ): Bitmap {
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
        paint.color = theme?.track ?: Color.parseColor("#33FFFFFF")
        c.drawArc(rect, 0f, 360f, false, paint)
        val p = percent.coerceIn(0, 100)
        if (p > 0) {
            paint.color = ringColor(mood)
            c.drawArc(rect, -90f, 360f * p / 100f, false, paint)
        }
        val inset = stroke + size * 0.03f
        val disc = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = theme?.disc ?: Color.WHITE }
        c.drawCircle(size / 2f, size / 2f, size / 2f - inset, disc)
        val m = mascot(context, mood, skin, skinPath)
        val useCustom = skin == "custom" && !skinPath.isNullOrEmpty() && File(skinPath).exists()
        if (m != null) {
            val inner = size - inset * 2f
            val bitmapPaint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
            if (useCustom) {
                // Gambar sendiri: potong persegi dari tengah, lalu bulatkan.
                val side = minOf(m.width, m.height)
                val src = Rect((m.width - side) / 2, (m.height - side) / 2, (m.width + side) / 2, (m.height + side) / 2)
                val r = inner / 2f
                val clip = Path()
                clip.addCircle(size / 2f, size / 2f, r, Path.Direction.CW)
                c.save()
                c.clipPath(clip)
                c.drawBitmap(m, src, RectF(size / 2f - r, size / 2f - r, size / 2f + r, size / 2f + r), bitmapPaint)
                c.restore()
            } else {
                // Maskot bawaan: muat di kotak 88% lingkaran dengan perbandingan asli.
                val box = inner * 0.88f
                val scale = minOf(box / m.width, box / m.height)
                val w = m.width * scale
                val h = m.height * scale
                val left = (size - w) / 2f
                val top = (size - h) / 2f
                c.drawBitmap(m, null, RectF(left, top, left + w, top + h), bitmapPaint)
            }
        }
        return bmp
    }
}
