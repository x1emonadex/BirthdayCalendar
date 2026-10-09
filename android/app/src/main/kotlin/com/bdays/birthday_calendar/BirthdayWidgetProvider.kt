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
/// одной записью, и с пятью.
///
/// Оформление — прозрачность подложки, число строк и заголовок — приходит из
/// экрана настроек виджета: он пишет в тот же файл настроек, что и приложение.
class BirthdayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val opacity = widgetData.getInt(
            BirthdayWidgetConfigActivity.KEY_OPACITY,
            BirthdayWidgetConfigActivity.DEFAULT_OPACITY,
        )
        val visibleLines = widgetData.getInt(
            BirthdayWidgetConfigActivity.KEY_LINES,
            BirthdayWidgetConfigActivity.DEFAULT_LINES,
        )
        val showTitle = widgetData.getBoolean(
            BirthdayWidgetConfigActivity.KEY_SHOW_TITLE,
            true,
        )

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.birthday_widget_layout).apply {
                setInt(R.id.widget_container, "setBackgroundResource", backgroundFor(opacity))

                setViewVisibility(
                    R.id.widget_title,
                    if (showTitle) View.VISIBLE else View.GONE,
                )
                setTextViewText(
                    R.id.widget_title,
                    widgetData.getString("widget_title", null) ?: "Дни рождения",
                )

                lineIds.forEachIndexed { index, viewId ->
                    val text = widgetData.getString("widget_line_${index + 1}", null)
                    val fits = index < visibleLines
                    if (!fits || text.isNullOrEmpty()) {
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

    /// Подложка нужной прозрачности.
    ///
    /// Ступени сделаны готовыми файлами: собрать полупрозрачный прямоугольник
    /// со скруглёнными углами в RemoteViews из кода нельзя, а подмена фона
    /// цветом потеряла бы скругление.
    private fun backgroundFor(opacity: Int): Int = when {
        opacity <= 20 -> R.drawable.widget_bg_20
        opacity <= 40 -> R.drawable.widget_bg_40
        opacity <= 60 -> R.drawable.widget_bg_60
        opacity <= 80 -> R.drawable.widget_bg_80
        else -> R.drawable.widget_bg_100
    }

    private companion object {
        val lineIds = listOf(
            R.id.widget_line_1,
            R.id.widget_line_2,
            R.id.widget_line_3,
            R.id.widget_line_4,
            R.id.widget_line_5,
        )
    }
}
