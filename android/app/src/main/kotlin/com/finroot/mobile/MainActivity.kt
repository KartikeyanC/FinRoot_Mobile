package com.finroot.mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    // Set when FinRoot was opened from a payment pop-up; Flutter takes it once.
    private var launchNotice: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchNotice = takeNoticeId(intent)
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

    // A pop-up tapped while FinRoot is already running.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        takeNoticeId(intent)?.let { channel?.invokeMethod("openNotice", it) }
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
