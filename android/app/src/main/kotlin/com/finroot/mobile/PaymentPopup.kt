package com.finroot.mobile

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

/**
 * The "₹500 paid — add to FinRoot?" pop-up posted the moment a payment is
 * detected. Tapping it (or its Add button) opens FinRoot straight into Quick
 * Add for that payment; MainActivity hands the notice id to Flutter.
 *
 * It only reads the amount and paid/received from the text to word the
 * pop-up — the Dart parser still decides what the payment really is.
 */
object PaymentPopup {
    const val EXTRA_NOTICE_ID = "com.finroot.mobile.PAYMENT_NOTICE_ID"
    private const val CHANNEL_ID = "payment_detected"

    // Same words the Dart parser rejects: requests, reminders, failures…
    private val NOT_A_PAYMENT = Regex(
        "\\b(request(?:ed|s)?|reminder|due (?:on|date|by)|is due|minimum (?:amount )?due|" +
            "will be (?:debited|credited|deducted)|scheduled|failed|declined|" +
            "unsuccessful|offer|win|get up to|bill (?:is )?generated)\\b",
        RegexOption.IGNORE_CASE,
    )
    private val CURRENCY_AMOUNT = Regex(
        "(?:₹|\\brs\\.?|\\binr)\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)",
        RegexOption.IGNORE_CASE,
    )
    private val BARE_AMOUNT = Regex(
        "\\b(?:debited|credited)\\s+(?:by|for|with)\\s+([0-9][0-9,]*(?:\\.[0-9]{1,2})?)",
        RegexOption.IGNORE_CASE,
    )
    private val BALANCE_BEFORE = Regex("\\b(bal(?:ance)?|lmt|limit)[^0-9]{0,12}$", RegexOption.IGNORE_CASE)
    private val DEBIT = Regex(
        "\\b(paid|sent|debited|spent|withdrawn|purchase|transferred|payment of|paying)\\b",
        RegexOption.IGNORE_CASE,
    )
    private val CREDIT = Regex(
        "\\b(received|credited|refund(?:ed)?|deposited|cashback|added to your)\\b",
        RegexOption.IGNORE_CASE,
    )

    fun show(ctx: Context, noticeId: String, title: String, text: String) {
        val all = "$title $text".replace(Regex("\\s+"), " ").trim()
        if (NOT_A_PAYMENT.containsMatchIn(all)) return
        val amount = amountIn(all) ?: return
        val d = DEBIT.find(all)?.range?.first
        val c = CREDIT.find(all)?.range?.first
        if (d == null && c == null) return
        val received = d == null || (c != null && c < d)

        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Detected payments",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Pops up when FinRoot spots a payment you made or received"
                },
            )
        }
        if (Build.VERSION.SDK_INT >= 33 &&
            ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return

        val open = PendingIntent.getActivity(
            ctx,
            noticeId.hashCode(),
            Intent(ctx, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(EXTRA_NOTICE_ID, noticeId),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val heading = if (received) {
            "$amount received — add to FinRoot?"
        } else {
            "$amount paid — add to FinRoot?"
        }
        val body = text.ifBlank { title }
        val action = if (received) "Add income" else "Add expense"

        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(ctx, CHANNEL_ID)
        } else {
            Notification.Builder(ctx).setPriority(Notification.PRIORITY_HIGH)
        }
        val n = builder
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setColor(0xFF0D7A5F.toInt())
            .setContentTitle(heading)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, action, open).build())
            .build()
        // Keyed by amount: the UPI app and the bank SMS for one payment
        // replace each other instead of popping up twice.
        nm.notify("payment:$amount:${if (received) "in" else "out"}".hashCode(), n)
    }

    private fun amountIn(text: String): String? {
        for (re in listOf(CURRENCY_AMOUNT, BARE_AMOUNT)) {
            for (m in re.findAll(text)) {
                if (BALANCE_BEFORE.containsMatchIn(text.substring(0, m.range.first))) continue
                val raw = m.groupValues[1].replace(",", "")
                val value = raw.toBigDecimalOrNull() ?: continue
                if (value.signum() <= 0) continue
                val plain = value.stripTrailingZeros()
                val digits = if (plain.scale() <= 0) {
                    "%,d".format(plain.toBigInteger())
                } else {
                    "%,.2f".format(value)
                }
                return "₹$digits"
            }
        }
        return null
    }
}
