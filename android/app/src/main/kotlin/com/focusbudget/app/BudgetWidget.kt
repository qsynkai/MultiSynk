package com.focusbudget.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class BudgetWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            // This runs inside the app process; a failure here must never take the app down.
            try {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                Log.e("BudgetWidget", "Widget update failed", e)
            }
        }
    }

    companion object {
        private val ROUTES = listOf(
            "multisynk://tab/0", "multisynk://tab/1", "multisynk://tab/4", "multisynk://fiorino",
        )

        // Plain PendingIntent instead of HomeWidgetLaunchIntent, which sets a background-activity
        // start option that newer Android versions reject. Action/data still match what the
        // home_widget plugin reads in Dart.
        private fun launchIntent(context: Context, uri: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = Uri.parse(uri)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(
                context, ROUTES.indexOf(uri) + 1, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val data = HomeWidgetPlugin.getData(context)
            fun str(key: String, default: String = "") = data.getString(key, default) ?: default

            val views = RemoteViews(context.packageName, R.layout.budget_widget)

            val dateStr = SimpleDateFormat("EEE, dd/MM", Locale("pt", "BR"))
                .format(Date())
                .replaceFirstChar { it.uppercase() }
            views.setTextViewText(R.id.widget_date, dateStr)

            views.setTextViewText(R.id.widget_budget, str("weekly_budget", "R$ 0,00"))
            views.setInt(
                R.id.widget_hero, "setBackgroundResource",
                if (str("budget_negative") == "1") R.drawable.widget_hero_bg_negative else R.drawable.widget_hero_bg
            )

            val fixed = str("pending_fixed")
            views.setTextViewText(R.id.widget_fixed, fixed)
            views.setViewVisibility(R.id.widget_fixed, if (fixed.isEmpty()) View.GONE else View.VISIBLE)

            views.setTextViewText(R.id.widget_receivables, str("receivables", "R$ 0,00"))
            views.setTextViewText(R.id.widget_expenses, str("month_expenses", "R$ 0,00"))
            views.setTextViewText(R.id.widget_fiorino, str("fiorino_today", "—"))

            val taskIds = intArrayOf(R.id.widget_task_1, R.id.widget_task_2, R.id.widget_task_3)
            val tasks = listOf(str("task_1"), str("task_2"), str("task_3"))
            if (tasks.all { it.isEmpty() }) {
                views.setTextViewText(R.id.widget_task_1, "Nenhuma tarefa pendente ✓")
                views.setViewVisibility(R.id.widget_task_1, View.VISIBLE)
                views.setViewVisibility(R.id.widget_task_2, View.GONE)
                views.setViewVisibility(R.id.widget_task_3, View.GONE)
            } else {
                tasks.forEachIndexed { i, title ->
                    views.setTextViewText(taskIds[i], "•  $title")
                    views.setViewVisibility(taskIds[i], if (title.isEmpty()) View.GONE else View.VISIBLE)
                }
            }

            val updated = str("updated_at")
            views.setTextViewText(R.id.widget_updated, if (updated.isEmpty()) "" else "Atualizado às $updated")

            fun open(uri: String) = launchIntent(context, uri)

            views.setOnClickPendingIntent(R.id.widget_root, open("multisynk://tab/0"))
            views.setOnClickPendingIntent(R.id.widget_tasks_box, open("multisynk://tab/4"))
            views.setOnClickPendingIntent(R.id.widget_btn_expense, open("multisynk://tab/1"))
            views.setOnClickPendingIntent(R.id.widget_btn_fiorino, open("multisynk://fiorino"))
            views.setOnClickPendingIntent(R.id.widget_btn_tasks, open("multisynk://tab/4"))

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
