package com.finroot.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

/**
 * The FinRoot home-screen widget: today's and this month's spend, the budget
 * left this month, the next bill due, and three buttons — Scan & pay (a
 * shop's UPI QR), Scan bill, and the floating Quick Add.
 *
 * It computes nothing. The app writes every figure, already formatted,
 * whenever the ledger changes (HomeWidgetStore, over the "finroot/home_widget"
 * channel), and the widget shows them. A figure written on an earlier day (or
 * month) reads as nothing spent, a bill whose day has passed is dropped, and
 * last month's budget is hidden, so the widget is right on a new morning
 * before the app is opened; the hourly update (finroot_widget_info.xml) is
 * what re-draws it then. Made short (2 rows), it keeps the spend and the
 * buttons and leaves the budget and bill lines out.
 */
class FinRootWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, views(context, manager, it)) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) {
        manager.updateAppWidget(id, views(context, manager, id))
    }

    companion object {
        /** MainActivity actions a widget button starts with. */
        const val ACTION_SCAN_PAY = "com.finroot.mobile.action.SCAN_PAY"
        const val ACTION_SCAN_BILL = "com.finroot.mobile.action.SCAN_BILL"

        /** Re-draws every FinRoot widget on the home screen. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            manager.getAppWidgetIds(ComponentName(context, FinRootWidget::class.java))
                .forEach { manager.updateAppWidget(it, views(context, manager, it)) }
            FinRootPayWidget.refresh(context)
        }

        private fun views(context: Context, manager: AppWidgetManager, id: Int): RemoteViews {
            val f = HomeWidgetStore.read(context)
            val v = RemoteViews(context.packageName, R.layout.finroot_widget)

            val now = Date()
            val day = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now)
            val month = SimpleDateFormat("yyyy-MM", Locale.US).format(now)
            val thisMonth = f.signedIn && f.monthKey == month
            val (today, spent) = when {
                !f.signedIn -> DASH to DASH
                f.masked -> MASK to MASK
                else -> (if (f.day == day) f.today else f.zero) to
                    (if (thisMonth) f.month else f.zero)
            }
            v.setTextViewText(R.id.widget_today, today)
            v.setTextViewText(R.id.widget_month, spent)

            // Two rows tall leaves room for the spend and the buttons only.
            val tall = manager.getAppWidgetOptions(id)
                ?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
                .let { it == null || it == 0 || it >= TALL_DP }

            val showBudget = tall && thisMonth && f.budget.isNotEmpty() && f.budgetPct >= 0
            v.setViewVisibility(R.id.widget_budget_box, if (showBudget) View.VISIBLE else View.GONE)
            if (showBudget) {
                v.setTextViewText(R.id.widget_budget, f.budget)
                v.setProgressBar(R.id.widget_budget_bar, 100, f.budgetPct, false)
                v.setViewVisibility(R.id.widget_budget_bar, if (f.budgetOver) View.GONE else View.VISIBLE)
                v.setViewVisibility(R.id.widget_budget_bar_over, if (f.budgetOver) View.VISIBLE else View.GONE)
            }

            val due = if (tall && f.signedIn) dueLine(f, now) else null
            v.setViewVisibility(R.id.widget_due, if (due != null) View.VISIBLE else View.GONE)
            if (due != null) v.setTextViewText(R.id.widget_due, due)

            v.setOnClickPendingIntent(R.id.widget_figures, open(context, null, 0))
            v.setOnClickPendingIntent(R.id.widget_budget_box, open(context, null, 0))
            v.setOnClickPendingIntent(R.id.widget_due, open(context, null, 0))
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

        /**
         * "Next due: Netflix ₹649 · tomorrow", worded against today so it
         * stays right overnight. Null once the day has passed.
         */
        private fun dueLine(f: HomeWidgetStore.Figures, now: Date): String? {
            if (f.dueTitle.isEmpty() || f.dueDay.isEmpty()) return null
            val due = try {
                SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(f.dueDay)
            } catch (e: java.text.ParseException) {
                null
            } ?: return null
            val today = Calendar.getInstance().apply {
                time = now
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.time
            val days = Math.round((due.time - today.time) / TimeUnit.DAYS.toMillis(1).toDouble())
            if (days < 0) return null
            val whenText = when (days) {
                0L -> "today"
                1L -> "tomorrow"
                in 2L..6L -> "in $days days"
                else -> SimpleDateFormat("d MMM", Locale.ENGLISH).format(due)
            }
            val amount = if (f.dueAmount.isEmpty()) "" else " ${f.dueAmount}"
            return "Next due: ${f.dueTitle}$amount · $whenText"
        }

        /** FinRoot itself, told which button was tapped ([action], or none). */
        internal fun open(context: Context, action: String?, request: Int): PendingIntent {
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

        /** Below this height (dp) the widget is two rows: spend and buttons only. */
        private const val TALL_DP = 170
        private const val DASH = "—"
        private const val MASK = "₹ ••••"
    }
}

/**
 * The small 2×2 widget: one green Scan & pay button, like a payment app's.
 * The whole tile opens Scan & pay; it shows no money at all.
 */
class FinRootPayWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        if (ids.isNotEmpty()) manager.updateAppWidget(ids, views(context))
    }

    companion object {
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(ComponentName(context, FinRootPayWidget::class.java))
            if (ids.isNotEmpty()) manager.updateAppWidget(ids, views(context))
        }

        private fun views(context: Context): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.finroot_pay_widget)
            v.setOnClickPendingIntent(
                R.id.pay_widget_root,
                FinRootWidget.open(context, FinRootWidget.ACTION_SCAN_PAY, 4),
            )
            return v
        }
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
        /** "yyyy-MM" that [month] and the budget belong to. */
        val monthKey: String,
        /** "₹6,400 left of ₹25,000"; empty when no budget is set. */
        val budget: String,
        /** 0–100, or -1 for none. */
        val budgetPct: Int,
        val budgetOver: Boolean,
        val dueTitle: String,
        val dueAmount: String,
        /** "yyyy-MM-dd". */
        val dueDay: String,
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
            .putString("budget", m["budget"] as? String ?: "")
            .putInt("budgetPct", (m["budgetPct"] as? Number)?.toInt() ?: -1)
            .putBoolean("budgetOver", m["budgetOver"] == true)
            .putString("dueTitle", m["dueTitle"] as? String ?: "")
            .putString("dueAmount", m["dueAmount"] as? String ?: "")
            .putString("dueDay", m["dueDay"] as? String ?: "")
            .apply()
    }

    /** Signed out: the widget shows dashes, not the last person's spend. */
    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }

    fun read(context: Context): Figures {
        val p = prefs(context)
        fun s(k: String, d: String = "") = p.getString(k, d) ?: d
        return Figures(
            signedIn = p.getBoolean("signedIn", false),
            masked = p.getBoolean("masked", false),
            today = s("today"),
            month = s("month"),
            zero = s("zero", "₹0"),
            day = s("day"),
            monthKey = s("monthKey"),
            budget = s("budget"),
            budgetPct = p.getInt("budgetPct", -1),
            budgetOver = p.getBoolean("budgetOver", false),
            dueTitle = s("dueTitle"),
            dueAmount = s("dueAmount"),
            dueDay = s("dueDay"),
        )
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
