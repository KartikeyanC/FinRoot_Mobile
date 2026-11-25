package com.finroot.mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.mlkit.common.MlKitException
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import io.flutter.plugin.common.MethodChannel

/**
 * Scan & pay ("finroot/upi"): read a shop's UPI QR, then hand the payment to
 * the person's own UPI app (Google Pay, PhonePe, Paytm, BHIM…). FinRoot never
 * moves money and never sees a UPI PIN; it only learns what the UPI app
 * reports back, and records the expense.
 *
 * The scanner is Google's code scanner (Play services): its own camera screen,
 * so FinRoot asks for no camera permission. On a phone that hasn't fetched the
 * scanner yet, the first try starts the download and reports "downloading".
 */
class UpiBridge(private val activity: Activity) {
    private var pending: MethodChannel.Result? = null

    fun scanQr(result: MethodChannel.Result) {
        val options = GmsBarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .enableAutoZoom()
            .build()
        val scanner = GmsBarcodeScanning.getClient(activity, options)
        scanner.startScan()
            .addOnSuccessListener { result.success(mapOf("code" to it.rawValue)) }
            .addOnCanceledListener { result.success(mapOf("cancelled" to true)) }
            .addOnFailureListener { e ->
                val missing = (e as? MlKitException)?.errorCode == MlKitException.UNAVAILABLE
                if (missing) {
                    // Ask Play services to fetch the scanner now, not "later".
                    ModuleInstall.getClient(activity).installModules(
                        ModuleInstallRequest.newBuilder().addApi(scanner).build(),
                    )
                }
                result.success(mapOf("error" to if (missing) "downloading" else "failed"))
            }
    }

    /** Opens a UPI app for [uri]; the answer comes in [onActivityResult]. */
    fun pay(uri: String, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
        if (intent.resolveActivity(activity.packageManager) == null) {
            result.success(mapOf("noApp" to true))
            return
        }
        // A second Pay before the first came back: the first gets no answer.
        pending?.success(mapOf("resultCode" to Activity.RESULT_CANCELED))
        pending = result
        @Suppress("DEPRECATION")
        activity.startActivityForResult(Intent.createChooser(intent, "Pay with"), REQUEST_PAY)
    }

    /** True when it was ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PAY) return false
        val r = pending ?: return true
        pending = null
        r.success(mapOf("resultCode" to resultCode, "response" to response(data)))
        return true
    }

    /**
     * The UPI app's answer, as the spec's "txnId=…&responseCode=…&Status=…"
     * string. Most apps send it as the "response" extra; some send the fields
     * as separate extras, which are joined into the same shape.
     */
    @Suppress("DEPRECATION") // Bundle.get: the extras' types vary by app.
    private fun response(data: Intent?): String? {
        data?.getStringExtra("response")?.takeIf { it.isNotBlank() }?.let { return it }
        val extras = data?.extras ?: return null
        return extras.keySet()
            .mapNotNull { k -> extras.get(k)?.let { "$k=$it" } }
            .joinToString("&")
            .takeIf { it.isNotBlank() }
    }

    companion object {
        private const val REQUEST_PAY = 7201
    }
}
