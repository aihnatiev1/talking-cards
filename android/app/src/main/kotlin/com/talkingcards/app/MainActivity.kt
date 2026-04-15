package com.talkingcards.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.talkingcards.app/engage"
    private var pendingLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        extractLink(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> result.success(pendingLink.also { pendingLink = null })
                    "publishContent" -> {
                        @Suppress("UNCHECKED_CAST")
                        EngagePublisher.publish(this, call.arguments as Map<String, Any?>)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        extractLink(intent)
    }

    private fun extractLink(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme == "talkingcards") pendingLink = uri.toString()
    }
}
