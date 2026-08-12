package ru.econizhny.eco_nizhny

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var oauthEvents: EventChannel.EventSink? = null
    private var pendingOAuthLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "eco_nizhny/oauth_links",
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    oauthEvents = events
                    pendingOAuthLink?.let { link ->
                        events?.success(link)
                        pendingOAuthLink = null
                    }
                }

                override fun onCancel(arguments: Any?) {
                    oauthEvents = null
                }
            },
        )

        handleOAuthIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleOAuthIntent(intent)
    }

    private fun handleOAuthIntent(intent: Intent?) {
        val link = intent?.dataString ?: return
        if (!link.startsWith("ecodesman://")) {
            return
        }

        val events = oauthEvents
        if (events == null) {
            pendingOAuthLink = link
        } else {
            events.success(link)
        }
    }
}
