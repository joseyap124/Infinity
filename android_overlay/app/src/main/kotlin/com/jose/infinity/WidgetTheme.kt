package com.jose.infinity

import android.graphics.Color

/**
 * Warna widget per gaya (v5.5). Kuncinya sama dengan stylePack di app:
 * "malam", "kuning", "merah"; selain itu dianggap Klasik (gradasi biru
 * kehijauan seperti sebelumnya). Latar berupa drawable bawaan per gaya.
 */
class WidgetTheme(
    val bg: Int,
    val fg: Int,
    val fg2: Int,
    val acc: Int,
    val track: Int,
    val disc: Int,
) {
    companion object {
        /** Widget bersih (tanpa maskot) untuk gaya Klasik; gaya lain tetap seperti sebelumnya. */
        fun isClean(pack: String?): Boolean =
            pack != "malam" && pack != "kuning" && pack != "merah"

        fun of(pack: String?, skin: String?): WidgetTheme {
            val disc = if (skin == "owl") Color.parseColor("#FFDCEEFF") else Color.WHITE
            return when (pack) {
                "malam" -> WidgetTheme(
                    R.drawable.infinity_widget_bg_malam,
                    Color.parseColor("#FFE6F6FF"),
                    Color.parseColor("#FF8FB4D9"),
                    Color.parseColor("#FF5FD3FF"),
                    Color.parseColor("#331EA7FF"),
                    disc,
                )
                "kuning" -> WidgetTheme(
                    R.drawable.infinity_widget_bg_kuning,
                    Color.parseColor("#FF14130A"),
                    Color.parseColor("#FF4A4630"),
                    Color.parseColor("#FF0B5D2A"),
                    Color.parseColor("#3314130A"),
                    disc,
                )
                "merah" -> WidgetTheme(
                    R.drawable.infinity_widget_bg_merah,
                    Color.parseColor("#FFFFF1DC"),
                    Color.parseColor("#FFD9B99B"),
                    Color.parseColor("#FFF2C27A"),
                    Color.parseColor("#33FFF1DC"),
                    disc,
                )
                else -> WidgetTheme(
                    R.drawable.infinity_widget_bg,
                    Color.WHITE,
                    Color.parseColor("#B3FFFFFF"),
                    Color.parseColor("#FF6EE79A"),
                    Color.parseColor("#33FFFFFF"),
                    disc,
                )
            }
        }
    }
}
