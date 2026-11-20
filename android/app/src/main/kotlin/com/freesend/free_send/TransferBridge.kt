package com.freesend.free_send

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Starts, updates, and stops the foreground service that keeps transfers alive. */
class TransferBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val events = EventChannel(messenger, EVENTS_CHANNEL)

    init {
        channel.setMethodCallHandler(this)
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (events != null) TransferEvents.attach(events)
            }

            override fun onCancel(arguments: Any?) {
                TransferEvents.detach()
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val title = call.argument<String>("title") ?: "Transfer in progress"
                val text = call.argument<String>("text") ?: "Sharing over the local network"
                val stopLabel = call.argument<String>("stopLabel")
                TransferService.start(context, title, text, stopLabel)
                result.success(null)
            }
            "update" -> {
                val title = call.argument<String>("title") ?: "Transfer in progress"
                val text = call.argument<String>("text") ?: "Sharing over the local network"
                TransferService.update(context, title, text)
                result.success(null)
            }
            "stop" -> {
                TransferService.stop(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val CHANNEL = "com.freesend.free_send/transfer"
        private const val EVENTS_CHANNEL = "com.freesend.free_send/transfer_events"
    }
}
