package com.example.agenda

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

class CaptureWidget : AppWidgetProvider() {
    companion object {
        /** Redraws every placed widget, so its label follows a new app language at once. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, CaptureWidget::class.java))
            if (ids.isNotEmpty()) update(context, manager, ids)
        }

        private fun update(context: Context, manager: AppWidgetManager, ids: IntArray) {
            // On Android 13+ the label comes from this app's resources, in the app's language (the
            // per-app language): the launcher would inflate the layout's text in the phone's.
            // Below 13 the layout's text follows the phone, as the app's resources do.
            val label = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) context.getString(R.string.capture_voice) else null
            for (id in ids) {
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = CaptureEntryBridge.VOICE
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val launch = PendingIntent.getActivity(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val views = RemoteViews(context.packageName, R.layout.capture_widget)
                views.setOnClickPendingIntent(R.id.capture_widget_button, launch)
                if (label != null) {
                    views.setTextViewText(R.id.capture_widget_label, label)
                    views.setContentDescription(R.id.capture_widget_button, label)
                }
                manager.updateAppWidget(id, views)
            }
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = update(context, manager, ids)
}
