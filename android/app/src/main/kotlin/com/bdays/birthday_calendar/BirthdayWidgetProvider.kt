package com.bdays.birthday_calendar

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Виджет на рабочем столе: ближайший день рождения и срок до него.
///
/// Тексты готовит приложение и кладёт в общие настройки виджета: логика дат
/// и склонений живёт в Dart и покрыта тестами, дублировать её здесь незачем.
class BirthdayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.birthday_widget_layout).apply {
                setTextViewText(
                    R.id.widget_when,
                    widgetData.getString("next_when", null) ?: "Нет записей",
                )
                setTextViewText(
                    R.id.widget_who,
                    widgetData.getString("next_who", null) ?: "Добавьте дни рождения",
                )
                // Нажатие открывает приложение.
                setOnClickPendingIntent(
                    R.id.widget_container,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
