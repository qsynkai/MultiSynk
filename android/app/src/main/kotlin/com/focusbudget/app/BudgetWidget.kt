package com.focusbudget.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class BudgetWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val widgetData = HomeWidgetPlugin.getData(context)

            val budget   = widgetData.getString("weekly_budget",    "R$ 0,00") ?: "R$ 0,00"
            val income   = widgetData.getString("total_income",     "R$ 0,00") ?: "R$ 0,00"
            val expenses = widgetData.getString("total_expenses",   "R$ 0,00") ?: "R$ 0,00"
            val fiorino  = widgetData.getString("fiorino_today",    "—")       ?: "—"

            val dateStr = SimpleDateFormat("EEE, dd/MM", Locale("pt", "BR"))
                .format(Date())
                .replaceFirstChar { it.uppercase() }

            val views = RemoteViews(context.packageName, R.layout.budget_widget)
            views.setTextViewText(R.id.widget_budget,   budget)
            views.setTextViewText(R.id.widget_income,   income)
            views.setTextViewText(R.id.widget_expenses, expenses)
            views.setTextViewText(R.id.widget_fiorino,  fiorino)
            views.setTextViewText(R.id.widget_date,     dateStr)

            // Toque abre o app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
