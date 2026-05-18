package com.example.wicara_mobile

import com.example.wicara_mobile.edge.LiteRtLmBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var liteRtBridge: LiteRtLmBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        liteRtBridge = LiteRtLmBridge(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LiteRtLmBridge.CHANNEL_NAME,
        ).setMethodCallHandler(liteRtBridge)
    }
}
