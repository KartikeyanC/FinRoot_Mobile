package com.finroot.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The floating Quick Add: a transparent window over whatever app the person
 * is in (opened from the quick-settings tile or the app-icon shortcut, e.g.
 * right after paying in a UPI app). Flutter renders only the
 * `/quick-add-float` card over a dimmed background; saving goes through the
 * app's normal offline-first Quick Add, and the Dart side finishes this
 * activity (SystemNavigator.pop) once the entry has been pushed. In between,
 * "hide" sends this task to the back, so the person is straight back in the
 * app they came from while the push finishes.
 *
 * Own task (taskAffinity ""), single instance, kept out of Recents.
 */
class QuickAddDialogActivity : FlutterActivity() {
    override fun getInitialRoute(): String = "/quick-add-float"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "finroot/quick_log")
            .setMethodCallHandler { call, result ->
                if (call.method == "hide") {
                    moveTaskToBack(true)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun finish() {
        super.finish()
        // No slide animation: the card should simply vanish.
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }
}
