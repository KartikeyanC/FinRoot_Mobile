package com.finroot.mobile

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

/**
 * "Scan & pay" tile in the quick-settings panel: one tap opens FinRoot's
 * Scan & pay (the shop's UPI QR scanner) from anywhere. A plain launcher
 * like QuickAddTileService — it reads nothing and needs no permission.
 */
@RequiresApi(Build.VERSION_CODES.N)
class ScanPayTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.apply {
            state = Tile.STATE_INACTIVE
            updateTile()
        }
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    override fun onClick() {
        super.onClick()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                FinRootWidget.open(this, FinRootWidget.ACTION_SCAN_PAY, 5),
            )
        } else {
            val intent = Intent(this, MainActivity::class.java)
                .setAction(FinRootWidget.ACTION_SCAN_PAY)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP,
                )
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
