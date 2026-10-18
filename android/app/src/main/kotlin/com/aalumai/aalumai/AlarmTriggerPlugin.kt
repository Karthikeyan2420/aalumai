package com.aalumai.aalumai

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

private const val TAG = "AalumaiAlarm"

/**
 * Dart <-> native bridge for the exact-alarm trigger pipeline.
 *
 * Dart stays the owner of alarm scheduling rules (it already computes which
 * slots an alarm needs); this plugin only mirrors those slots into `AlarmManager`
 * so the ring service can start without a running Flutter engine, and exposes
 * the running state so the ringing screen knows whether to play audio itself.
 */
class AlarmTriggerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "aalumai/alarm_trigger"

        @Volatile
        private var activeChannel: MethodChannel? = null

        /**
         * An alarm id delivered by a cold-start launch intent, consumed by Dart
         * via `takePendingOpenAlarm` once its navigator is ready.
         */
        @Volatile
        private var pendingOpenAlarmId: Int = -1

        /** Tells a live Flutter engine that the ring just started. */
        fun notifyRingStarted(alarmId: Int) {
            Log.i(TAG, "notifyRingStarted($alarmId) channel=${activeChannel != null}")
            activeChannel?.invokeMethod("ringStarted", alarmId)
        }

        /**
         * Hands an alarm id to Dart. Delivered straight away when the engine is
         * attached, otherwise stashed for the next `takePendingOpenAlarm`.
         */
        fun deliverOpenAlarm(alarmId: Int) {
            val channel = activeChannel
            Log.i(TAG, "deliverOpenAlarm($alarmId) channel=${channel != null}")
            if (channel != null) {
                channel.invokeMethod("openAlarm", alarmId)
            } else {
                pendingOpenAlarmId = alarmId
            }
        }

        /** Records an alarm id from a cold-start launch intent. */
        fun setPendingOpenAlarm(alarmId: Int) {
            Log.i(TAG, "setPendingOpenAlarm($alarmId)")
            pendingOpenAlarmId = alarmId
        }
    }

    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
        activeChannel = channel
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        if (activeChannel === channel) activeChannel = null
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val appContext = context
        if (appContext == null) {
            result.error("detached", "Alarm trigger plugin is not attached", null)
            return
        }
        when (call.method) {
            "syncAlarm" -> {
                val alarmId = call.argument<Int>("alarmId")
                val raw = call.argument<String>("payloadsJson")
                if (alarmId == null || raw == null) {
                    result.error("bad_args", "syncAlarm requires alarmId and payloadsJson", null)
                    return
                }
                val parsed = ArrayList<AlarmTriggerPayload>()
                try {
                    val array = JSONArray(raw)
                    for (index in 0 until array.length()) {
                        val payload = AlarmTriggerPayload.fromJson(array.getJSONObject(index).toString())
                        if (payload != null && payload.alarmId == alarmId) parsed.add(payload)
                    }
                } catch (e: Exception) {
                    result.error("bad_payload", e.message, null)
                    return
                }
                val keep = parsed.mapTo(HashSet()) { it.slotId }
                for (existing in AlarmTriggerStore.all(appContext)) {
                    if (existing.alarmId == alarmId && existing.slotId !in keep) {
                        AlarmTriggerScheduler.cancel(appContext, existing.slotId)
                        AlarmTriggerStore.remove(appContext, existing.slotId)
                    }
                }
                for (payload in parsed) {
                    AlarmTriggerStore.put(appContext, payload)
                    AlarmTriggerScheduler.schedule(appContext, payload)
                }
                result.success(true)
            }

            "cancelAlarm" -> {
                val alarmId = call.argument<Int>("alarmId")
                if (alarmId == null) {
                    result.error("bad_args", "cancelAlarm requires alarmId", null)
                    return
                }
                cancelAlarm(appContext, alarmId)
                result.success(true)
            }

            "cancelSlots" -> {
                val slots = call.argument<List<Int>>("slotIds")
                if (slots == null) {
                    result.error("bad_args", "cancelSlots requires slotIds", null)
                    return
                }
                for (slotId in slots) {
                    AlarmTriggerScheduler.cancel(appContext, slotId)
                    AlarmTriggerStore.remove(appContext, slotId)
                }
                result.success(true)
            }

            "clearAll" -> {
                for (payload in AlarmTriggerStore.all(appContext)) {
                    AlarmTriggerScheduler.cancel(appContext, payload.slotId)
                }
                AlarmTriggerStore.clearAll(appContext)
                result.success(true)
            }

            "stop" -> {
                AlarmAudioService.requestStop(appContext)
                result.success(true)
            }

            "isRinging" -> {
                result.success(
                    mapOf(
                        "ringing" to AlarmAudioService.isRinging,
                        "alarmId" to AlarmAudioService.ringingAlarmId,
                    ),
                )
            }

            "takePendingOpenAlarm" -> {
                val pending = pendingOpenAlarmId
                pendingOpenAlarmId = -1
                result.success(pending.takeIf { it >= 0 })
            }

            else -> result.notImplemented()
        }
    }

    private fun cancelAlarm(appContext: Context, alarmId: Int) {
        for (payload in AlarmTriggerStore.all(appContext)) {
            if (payload.alarmId != alarmId) continue
            AlarmTriggerScheduler.cancel(appContext, payload.slotId)
            AlarmTriggerStore.remove(appContext, payload.slotId)
        }
        Log.d(TAG, "Cancelled native triggers for alarm $alarmId")
    }
}
