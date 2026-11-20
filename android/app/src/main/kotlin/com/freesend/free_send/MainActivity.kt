package com.freesend.free_send

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        HotspotBridge(applicationContext, messenger)
        UpdateBridge(applicationContext, messenger)
        TransferBridge(applicationContext, messenger)
        AppPackagesBridge(applicationContext, messenger)
        SafBridge(applicationContext, messenger)
        NetworkProbeBridge(applicationContext, messenger)
        // A cold start through the notification arrives with the navigate
        // extra already set; it is queued until Dart subscribes.
        handleNavigateIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNavigateIntent(intent)
    }

    private fun handleNavigateIntent(intent: Intent?) {
        if (intent?.getStringExtra(TransferService.EXTRA_NAVIGATE_KEY) ==
            TransferService.NAVIGATE_RECEIVE_VALUE
        ) {
            TransferEvents.emit(TransferService.EVENT_OPEN_RECEIVE)
        }
    }
}
