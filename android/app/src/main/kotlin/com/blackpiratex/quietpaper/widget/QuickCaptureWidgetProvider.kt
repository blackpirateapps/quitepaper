package com.blackpiratex.quietpaper.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.blackpiratex.quietpaper.MainActivity
import com.blackpiratex.quietpaper.R

/**
 * AppWidgetProvider for the compact Quiet Paper Quick Capture home-screen widget.
 * Provides a single prominent action to immediately launch Quick Capture.
 */
class QuickCaptureWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_QUICK_CAPTURE = "com.blackpiratex.quietpaper.QUICK_CAPTURE"
        const val REQUEST_CODE_CAPTURE = 1001

        fun buildUpdate(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_quick_capture)

            val intent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_QUICK_CAPTURE
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("origin", "widget")
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                REQUEST_CODE_CAPTURE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.widget_capture_button, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            return views
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = buildUpdate(context)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
