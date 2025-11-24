package com.example.tingyue

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.alipay.sdk.app.PayTask
import android.os.Handler
import android.os.Looper

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.tts_app/payment"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "alipay") {
                val orderString = call.argument<String>("orderString")
                if (orderString != null) {
                    payV2(orderString, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Order string is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun payV2(orderInfo: String, result: MethodChannel.Result) {
        val payRunnable = Runnable {
            val alipay = PayTask(this)
            val resultStatus = alipay.payV2(orderInfo, true)
            
            Handler(Looper.getMainLooper()).post {
                result.success(resultStatus)
            }
        }
        val payThread = Thread(payRunnable)
        payThread.start()
    }
}
