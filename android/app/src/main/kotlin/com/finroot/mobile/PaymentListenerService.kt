package com.finroot.mobile

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * Payment detection: watches notifications from UPI / bank apps (and, if the
 * user opts in, SMS apps for bank alerts) and keeps the ones that look like a
 * payment in a small on-device queue. The Flutter side reads the queue, parses
 * each entry and asks the user to confirm before anything is saved.
 *
 * Nothing leaves the device here, nothing is stored unless the user turned
 * detection on in the app, and OTP / verification messages are never kept.
 */
class PaymentListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val ctx = applicationContext
        if (!PaymentCaptureStore.isEnabled(ctx)) return
        val pkg = sbn.packageName
        val isSms = pkg in SMS_APPS
        if (!isSms && pkg !in PAYMENT_APPS) return
        if (isSms && !PaymentCaptureStore.isSmsEnabled(ctx)) return
        // Summary notifications repeat a child's text.
        if (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val extras = sbn.notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        val all = "$title $text"
        if (!looksLikePayment(all)) return

        val id = PaymentCaptureStore.add(ctx, pkg, title, text, sbn.postTime) ?: return
        if (PaymentCaptureStore.isPopupEnabled(ctx)) {
            PaymentPopup.show(ctx, id, title, text)
        }
    }

    companion object {
        /** UPI, wallet and bank apps whose notifications report payments. */
        val PAYMENT_APPS = setOf(
            "com.google.android.apps.nbu.paisa.user", // Google Pay
            "com.phonepe.app",
            "net.one97.paytm",
            "in.org.npci.upiapp", // BHIM
            "in.amazon.mShop.android.shopping", // Amazon Pay
            "com.dreamplug.androidapp", // CRED
            "com.mobikwik_new",
            "com.freecharge.android",
            "money.super.payments",
            "com.fampay.in",
            "com.sbi.lotusintouch", // SBI YONO
            "com.sbi.upi", // BHIM SBI Pay
            "com.snapwork.hdfc",
            "com.hdfcbank.payzapp",
            "com.csam.icici.bank.imobile",
            "com.axis.mobile",
            "com.msf.kbank.mobile", // Kotak
            "com.canarabank.mobility",
            "com.bankofbaroda.mconnect",
            "com.infrasoft.uboi", // Union Bank
            "com.fss.indus",
            "com.idfcfirstbank.optimus",
            "com.YesBank",
            "com.pnb.pnbone",
        )

        /** SMS apps — bank debit / credit alerts arrive as SMS. Opt-in. */
        val SMS_APPS = setOf(
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
            "com.android.mms",
            "com.android.messaging",
            "com.oneplus.mms",
            "com.miui.smsextra",
            "com.truecaller",
            "com.microsoft.android.smsorganizer",
        )

        private val OTP = Regex(
            "\\b(otp|one[ -]?time password|verification code|passcode)\\b",
            RegexOption.IGNORE_CASE,
        )
        private val MONEY_WORD = Regex(
            "\\b(paid|sent|debited|spent|payment|transferred|received|credited|withdrawn|purchase|txn|transaction)\\b",
            RegexOption.IGNORE_CASE,
        )
        private val DIGIT = Regex("\\d")

        /** Cheap first pass; the Dart parser decides for real. */
        fun looksLikePayment(s: String): Boolean =
            !OTP.containsMatchIn(s) && MONEY_WORD.containsMatchIn(s) &&
                DIGIT.containsMatchIn(s)

        fun hasAccess(ctx: Context): Boolean {
            val enabled = Settings.Secure.getString(
                ctx.contentResolver, "enabled_notification_listeners",
            ) ?: return false
            val me = ComponentName(ctx, PaymentListenerService::class.java)
            return enabled.split(':').any {
                ComponentName.unflattenFromString(it) == me
            }
        }
    }
}

/** The on-device queue of detected payments, in SharedPreferences. */
object PaymentCaptureStore {
    private const val PREFS = "finroot_payment_capture"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_SMS = "sms_enabled"
    private const val KEY_POPUP = "popup_enabled"
    private const val KEY_QUEUE = "queue"
    private const val MAX_ITEMS = 200
    private const val MAX_AGE_MS = 30L * 24 * 60 * 60 * 1000
    private const val REPOST_WINDOW_MS = 10L * 60 * 1000

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isEnabled(ctx: Context) = prefs(ctx).getBoolean(KEY_ENABLED, false)
    fun isSmsEnabled(ctx: Context) = prefs(ctx).getBoolean(KEY_SMS, false)
    fun isPopupEnabled(ctx: Context) = prefs(ctx).getBoolean(KEY_POPUP, true)

    fun setPopupEnabled(ctx: Context, on: Boolean) =
        prefs(ctx).edit().putBoolean(KEY_POPUP, on).apply()

    fun setEnabled(ctx: Context, on: Boolean) {
        val p = prefs(ctx).edit().putBoolean(KEY_ENABLED, on)
        // Turning detection off also forgets what it collected.
        if (!on) p.remove(KEY_QUEUE)
        p.apply()
    }

    fun setSmsEnabled(ctx: Context, on: Boolean) =
        prefs(ctx).edit().putBoolean(KEY_SMS, on).apply()

    /** Queues a notice; returns its id, or null when it was a repost. */
    @Synchronized
    fun add(ctx: Context, pkg: String, title: String, text: String, postedAt: Long): String? {
        val items = read(ctx)
        // Apps re-post (update) the same notification; keep one copy.
        for (i in 0 until items.length()) {
            val o = items.getJSONObject(i)
            if (o.optString("package") == pkg && o.optString("title") == title &&
                o.optString("text") == text &&
                Math.abs(o.optLong("postedAt") - postedAt) < REPOST_WINDOW_MS
            ) return null
        }
        val id = "$pkg:$postedAt:${(title + text).hashCode()}"
        items.put(
            JSONObject()
                .put("id", id)
                .put("package", pkg)
                .put("title", title)
                .put("text", text)
                .put("postedAt", postedAt),
        )
        write(ctx, items)
        return id
    }

    @Synchronized
    fun pending(ctx: Context): String = read(ctx).toString()

    @Synchronized
    fun remove(ctx: Context, ids: Collection<String>) {
        val items = read(ctx)
        val kept = JSONArray()
        for (i in 0 until items.length()) {
            val o = items.getJSONObject(i)
            if (o.optString("id") !in ids) kept.put(o)
        }
        write(ctx, kept)
    }

    private fun read(ctx: Context): JSONArray {
        val raw = prefs(ctx).getString(KEY_QUEUE, null) ?: return JSONArray()
        val all = try { JSONArray(raw) } catch (_: Exception) { return JSONArray() }
        val cutoff = System.currentTimeMillis() - MAX_AGE_MS
        val fresh = JSONArray()
        for (i in 0 until all.length()) {
            val o = all.optJSONObject(i) ?: continue
            if (o.optLong("postedAt") >= cutoff) fresh.put(o)
        }
        return fresh
    }

    private fun write(ctx: Context, items: JSONArray) {
        // Oldest first; drop the oldest past the cap.
        val start = maxOf(0, items.length() - MAX_ITEMS)
        val capped = JSONArray()
        for (i in start until items.length()) capped.put(items.get(i))
        prefs(ctx).edit().putString(KEY_QUEUE, capped.toString()).apply()
    }
}
