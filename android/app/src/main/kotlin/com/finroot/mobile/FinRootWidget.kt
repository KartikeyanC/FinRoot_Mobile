package com.finroot.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The FinRoot home-screen widget: today's and this month's spend, and three
 * buttons — Scan & pay (a shop's UPI QR), Scan bill, and the floating Quick
 * Add.
 *
 * It computes nothing. The app writes both figures, already formatted,
 * whenever the ledger changes (HomeWidgetStore, over the "finroot/home_widget"
 * channel), and the widget shows them. A figure written on an earlier day (or
 * month) reads as nothing spent, so the widget is right on a new morning
 * before the app is opened; the hourly update (finroot_widget_info.xml) is
 * what re-draws it then.
 */
class FinRootWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        if (ids.isNotEmpty()) manager.updateAppWidget(ids, views(context))
    }

    companion object {
        /** MainActivity actions a widget button starts with. */
        const val ACTION_SCAN_PAY = "com.finroot.mobile.action.SCAN_PAY"
        const val ACTION_SCAN_BILL = "com.finroot.mobile.action.SCAN_BILL"

        /** Re-draws every FinRoot widget on the home screen. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(ComponentName(context, FinRootWidget::class.java))
            if (ids.isNotEmpty()) manager.updateAppWidget(ids, views(context))
        }

        private fun views(context: Context): RemoteViews {
            val f = HomeWidgetStore.read(context)
            val v = RemoteViews(context.packageName, R.layout.finroot_widget)

            val now = Date()
            val day = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now)
            val month = SimpleDateFormat("yyyy-MM", Locale.US).format(now)
            val (today, thisMonth) = when {
                !f.signedIn -> DASH to DASH
                f.masked -> MASK to MASK
                else -> (if (f.day == day) f.today else f.zero) to
                    (if (f.monthKey == month) f.month else f.zero)
            }
            v.setTextViewText(R.id.widget_today, today)
            v.setTextViewText(R.id.widget_month, thisMonth)

            v.setOnClickPendingIntent(R.id.widget_figures, open(context, null, 0))
            v.setOnClickPendingIntent(R.id.widget_pay, open(context, ACTION_SCAN_PAY, 1))
            v.setOnClickPendingIntent(R.id.widget_bill, open(context, ACTION_SCAN_BILL, 2))
            v.setOnClickPendingIntent(
                R.id.widget_add,
                PendingIntent.getActivity(
                    context,
                    3,
                    Intent(context, QuickAddDialogActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
            return v
        }

        /** FinRoot itself, told which button was tapped ([action], or none). */
        private fun open(context: Context, action: String?, request: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java)
                .setAction(action ?: Intent.ACTION_MAIN)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP,
                )
            return PendingIntent.getActivity(
                context,
                request,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        private const val DASH = "—"
        private const val MASK = "₹ ••••"
    }
}

/**
 * What the widget shows, written by the app (MainActivity's "finroot/home_widget"
 * channel) and read by [FinRootWidget]. Formatted strings only — the widget
 * never sees a transaction.
 */
object HomeWidgetStore {
    private const val PREFS = "finroot_home_widget"

    data class Figures(
        val signedIn: Boolean,
        val masked: Boolean,
        val today: String,
        val month: String,
        /** Zero in the same format, for a day or month that has moved on. */
        val zero: String,
        /** "yyyy-MM-dd" that [today] belongs to. */
        val day: String,
        /** "yyyy-MM" that [month] belongs to. */
        val monthKey: String,
    )

    fun write(context: Context, m: Map<*, *>) {
        prefs(context).edit()
            .putBoolean("signedIn", true)
            .putBoolean("masked", m["masked"] == true)
            .putString("today", m["today"] as? String ?: "")
            .putString("month", m["month"] as? String ?: "")
            .putString("zero", m["zero"] as? String ?: "₹0")
            .putString("day", m["day"] as? String ?: "")
            .putString("monthKey", m["monthKey"] as? String ?: "")
            .apply()
    }

    /** Signed out: the widget shows dashes, not the last person's spend. */
    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }

    fun read(context: Context): Figures {
        val p = prefs(context)
        return Figures(
            signedIn = p.getBoolean("signedIn", false),
            masked = p.getBoolean("masked", false),
            today = p.getString("today", "") ?: "",
            month = p.getString("month", "") ?: "",
            zero = p.getString("zero", "₹0") ?: "₹0",
            day = p.getString("day", "") ?: "",
            monthKey = p.getString("monthKey", "") ?: "",
        )
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
