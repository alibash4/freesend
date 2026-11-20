package com.freesend.free_send

import io.flutter.plugin.common.EventChannel

/**
 * Tiny event bus between native components (the foreground service, the
 * activity) and Dart. Events emitted before Dart subscribes are queued so a
 * cold start through a notification action is not lost.
 */
object TransferEvents {
    private const val MAX_PENDING = 32

    private val lock = Any()
    private val pending = ArrayDeque<String>()
    private var sink: EventChannel.EventSink? = null

    fun emit(event: String) {
        val current = synchronized(lock) { sink }
        if (current != null) {
            try {
                current.success(event)
                return
            } catch (_: Exception) {
                // The Dart side went away; fall through and re-queue.
            }
        }
        synchronized(lock) {
            pending.addLast(event)
            while (pending.size > MAX_PENDING) pending.removeFirst()
        }
    }

    fun attach(events: EventChannel.EventSink) {
        val drained = synchronized(lock) {
            sink = events
            val copy = pending.toList()
            pending.clear()
            copy
        }
        for (event in drained) {
            try {
                events.success(event)
            } catch (_: Exception) {
                // Ignore a single stale event.
            }
        }
    }

    fun detach() {
        synchronized(lock) { sink = null }
    }
}
