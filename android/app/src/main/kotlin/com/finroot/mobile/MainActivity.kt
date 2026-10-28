package com.finroot.mobile

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Payment detection (see PaymentListenerService).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "finroot/payment_capture",
        ).setMethodCallHandler { call, result ->
            val ctx = applicationContext
            when (call.method) {
                "status" -> result.success(
                    mapOf(
                        "enabled" to PaymentCaptureStore.isEnabled(ctx),
                        "smsEnabled" to PaymentCaptureStore.isSmsEnabled(ctx),
                        "hasAccess" to PaymentListenerService.hasAccess(ctx),
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
                "openAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "pending" -> result.success(PaymentCaptureStore.pending(ctx))
                "remove" -> {
                    @Suppress("UNCHECKED_CAST")
                    PaymentCaptureStore.remove(ctx, call.arguments as List<String>)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
