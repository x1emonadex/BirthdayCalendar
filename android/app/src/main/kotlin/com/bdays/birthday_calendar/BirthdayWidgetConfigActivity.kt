package com.bdays.birthday_calendar

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView

/// Экран настроек виджета.
///
/// Открывается при добавлении виджета и по кнопке «Настройки» при долгом
/// нажатии. Кнопку показывает только лаунчер и только тем виджетам, у которых
/// объявлена конфигурационная активность — без неё настройки виджета открыть
/// нечем.
///
/// Настройки лежат в том же файле, что и данные для виджета
/// (`HomeWidgetPreferences`), поэтому провайдер видит их без лишней передачи.
class BirthdayWidgetConfigActivity : Activity() {

    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private lateinit var opacity: SeekBar
    private lateinit var lines: SeekBar
    private lateinit var showTitle: Switch
    private lateinit var opacityValue: TextView
    private lateinit var linesValue: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // По умолчанию виджет не добавляется: если пользователь закроет экран,
        // на рабочем столе ничего не должно появиться.
        setResult(RESULT_CANCELED)

        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.birthday_widget_config)

        val prefs = getSharedPreferences(PREFERENCES, MODE_PRIVATE)

        opacity = findViewById(R.id.config_opacity)
        lines = findViewById(R.id.config_lines)
        showTitle = findViewById(R.id.config_show_title)
        opacityValue = findViewById(R.id.config_opacity_value)
        linesValue = findViewById(R.id.config_lines_value)

        opacity.max = OPACITIES.lastIndex
        opacity.progress = indexOfOpacity(prefs.getInt(KEY_OPACITY, DEFAULT_OPACITY))
        lines.max = MAX_LINES - MIN_LINES
        lines.progress = prefs.getInt(KEY_LINES, DEFAULT_LINES) - MIN_LINES
        showTitle.isChecked = prefs.getBoolean(KEY_SHOW_TITLE, true)

        fun refreshLabels() {
            opacityValue.text = "${OPACITIES[opacity.progress]}%"
            linesValue.text = "${MIN_LINES + lines.progress}"
        }
        refreshLabels()

        val listener = object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(bar: SeekBar?, progress: Int, fromUser: Boolean) {
                refreshLabels()
            }

            override fun onStartTrackingTouch(bar: SeekBar?) = Unit

            override fun onStopTrackingTouch(bar: SeekBar?) = Unit
        }
        opacity.setOnSeekBarChangeListener(listener)
        lines.setOnSeekBarChangeListener(listener)

        findViewById<Button>(R.id.config_save).setOnClickListener { save() }
        findViewById<Button>(R.id.config_cancel).setOnClickListener { finish() }
    }

    private fun save() {
        getSharedPreferences(PREFERENCES, MODE_PRIVATE).edit()
            .putInt(KEY_OPACITY, OPACITIES[opacity.progress])
            .putInt(KEY_LINES, MIN_LINES + lines.progress)
            .putBoolean(KEY_SHOW_TITLE, showTitle.isChecked)
            .apply()

        // Просим виджет перерисоваться: он сам прочитает новые настройки.
        // Собирать разметку здесь второй раз не нужно — она живёт в провайдере.
        sendBroadcast(
            Intent(this, BirthdayWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId))
            },
        )

        setResult(
            RESULT_OK,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
        )
        finish()
    }

    companion object {
        /// Файл настроек, в который пишет и приложение, и виджет.
        const val PREFERENCES = "HomeWidgetPreferences"

        const val KEY_OPACITY = "widget_opacity"
        const val KEY_LINES = "widget_lines"
        const val KEY_SHOW_TITLE = "widget_show_title"

        const val DEFAULT_OPACITY = 80
        const val DEFAULT_LINES = 3
        const val MIN_LINES = 1
        const val MAX_LINES = 5

        /// Ступени прозрачности. Каждой соответствует своя готовая подложка:
        /// собрать полупрозрачный прямоугольник со скруглёнными углами в
        /// RemoteViews из кода нельзя, а подменять фон цветом — значит потерять
        /// скругление.
        val OPACITIES = intArrayOf(20, 40, 60, 80, 100)

        fun indexOfOpacity(value: Int): Int {
            val index = OPACITIES.indexOf(value)
            return if (index >= 0) index else OPACITIES.indexOf(DEFAULT_OPACITY)
        }
    }
}
