package com.finroot.mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity so local_auth can show the fingerprint / screen-lock
// prompt (hidden income).
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null

    // Set when FinRoot was opened from a payment pop-up; Flutter takes it once.
    private var launchNotice: String? = null

    // Set when FinRoot was opened by sharing text to it (a bank SMS from the
    // Messages app); Flutter takes it once.
    private var launchShared: String? = null

    // Set when FinRoot was opened from a home-screen widget button
    // ("scanPay" / "scanBill"); Flutter takes it once.
    private var launchWidgetAction: String? = null
    private var widgetChannel: MethodChannel? = null
    private val upi = UpiBridge(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchNotice = takeNoticeId(intent)
        launchShared = takeSharedText(intent)
        launchWidgetAction = takeWidgetAction(intent)
        // Home-screen widget (FinRootWidget): the app hands it today's and
        // this month's spend; a widget button that opened FinRoot is taken once.
        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "finroot/home_widget",
        ).also { it.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    HomeWidgetStore.write(applicationContext, call.arguments as Map<*, *>)
                    FinRootWidget.refresh(applicationContext)
                    result.success(null)
                }
                "clear" -> {
                    HomeWidgetStore.clear(applicationContext)
                    FinRootWidget.refresh(applicationContext)
                    result.success(null)
                }
                "takeLaunchAction" -> {
                    result.success(launchWidgetAction)
                    launchWidgetAction = null
                }
                else -> result.notImplemented()
            }
        } }
        // Scan & pay: a shop's UPI QR, paid in the person's own UPI app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "finroot/upi")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanQr" -> upi.scanQr(result)
                    "pay" -> upi.pay(call.arguments as String, result)
                    else -> result.notImplemented()
                }
            }
        // Payment detection (see PaymentListenerService / PaymentPopup).
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "finroot/payment_capture",
        ).also { it.setMethodCallHandler { call, result ->
            val ctx = applicationContext
            when (call.method) {
                "status" -> result.success(
                    mapOf(
                        "enabled" to PaymentCaptureStore.isEnabled(ctx),
                        "smsEnabled" to PaymentCaptureStore.isSmsEnabled(ctx),
                        "popupEnabled" to PaymentCaptureStore.isPopupEnabled(ctx),
                        "canPostNotifications" to canPostNotifications(),
                        "hasAccess" to PaymentListenerService.hasAccess(ctx),
                        // False in side-loaded builds, which leave the listener
                        // service out (see src/noPaymentDetection/).
                        "included" to listenerIncluded(),
                    ),
                )
                "setEnabled" -> {
                    PaymentCaptureStore.setEnabled(ctx, call.arguments as Boolean)
                    result.success(null)
                }
                "setSmsEnabled" -> {
                    PaymentCaptureStore.setSmsEnabled(ctx, call.arguments as Boolean)
                    result.success(null)
                }
                "setPopupEnabled" -> {
                    PaymentCaptureStore.setPopupEnabled(ctx, call.arguments as Boolean)
                    result.success(null)
                }
                "requestPopupPermission" -> {
                    if (!canPostNotifications() && Build.VERSION.SDK_INT >= 33) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7101)
                    }
                    result.success(null)
                }
                "openAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "takeLaunchNotice" -> {
                    result.success(launchNotice)
                    launchNotice = null
                }
                "takeSharedText" -> {
                    result.success(launchShared)
                    launchShared = null
                }
                "pending" -> result.success(PaymentCaptureStore.pending(ctx))
                "remove" -> {
                    @Suppress("UNCHECKED_CAST")
                    PaymentCaptureStore.remove(ctx, call.arguments as List<String>)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } }
    }

    // A pop-up tapped, or text shared, while FinRoot is already running.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        takeNoticeId(intent)?.let { channel?.invokeMethod("openNotice", it) }
        takeSharedText(intent)?.let { channel?.invokeMethod("sharedText", it) }
        takeWidgetAction(intent)?.let { widgetChannel?.invokeMethod("action", it) }
    }

    @Deprecated("The UPI app's answer comes back through the old result API.")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!upi.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    private fun takeWidgetAction(intent: Intent?): String? {
        if (intent == null) return null
        val action = when (intent.action) {
            FinRootWidget.ACTION_SCAN_PAY -> "scanPay"
            FinRootWidget.ACTION_SCAN_BILL -> "scanBill"
            else -> return null
        }
        // Don't act on it again on a configuration change / recreate.
        intent.action = null
        return action
    }

    private fun takeSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("text/") != true) return null
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        // Don't hand it over again on a configuration change / recreate.
        intent.removeExtra(Intent.EXTRA_TEXT)
        intent.action = null
        return text?.takeIf { it.isNotBlank() }
    }

    private fun takeNoticeId(intent: Intent?): String? {
        val id = intent?.getStringExtra(PaymentPopup.EXTRA_NOTICE_ID) ?: return null
        // Don't reopen it on a configuration change / recreate.
        intent.removeExtra(PaymentPopup.EXTRA_NOTICE_ID)
        return id
    }

    private fun listenerIncluded(): Boolean = try {
        packageManager.getServiceInfo(
            android.content.ComponentName(this, PaymentListenerService::class.java),
            0,
        )
        true
    } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
        false
    }

    private fun canPostNotifications() = Build.VERSION.SDK_INT < 33 ||
        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
        PackageManager.PERMISSION_GRANTED
}
