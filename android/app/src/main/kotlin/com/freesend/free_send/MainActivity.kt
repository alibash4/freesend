package com.freesend.free_send

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
    }
}
