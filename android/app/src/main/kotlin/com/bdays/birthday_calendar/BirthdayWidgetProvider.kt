package com.bdays.birthday_calendar

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Виджет на рабочем столе: ближайшие дни рождения и сроки до них.
///
/// Тексты готовит приложение и кладёт в общие настройки виджета: логика дат
/// и склонений живёт в Dart и покрыта тестами, дублировать её здесь незачем.
/// Пустые строки прячем, поэтому виджет выглядит одинаково аккуратно и с
/// одной записью, и с тремя.
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
                    R.id.widget_title,
                    widgetData.getString("widget_title", null) ?: "Дни рождения",
                )

                val lineIds = listOf(
                    R.id.widget_line_1,
                    R.id.widget_line_2,
                    R.id.widget_line_3,
                )
                lineIds.forEachIndexed { index, viewId ->
                    val text = widgetData.getString("widget_line_${index + 1}", null)
                    if (text.isNullOrEmpty()) {
                        setViewVisibility(viewId, View.GONE)
                    } else {
                        setViewVisibility(viewId, View.VISIBLE)
                        setTextViewText(viewId, text)
                    }
                }

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
