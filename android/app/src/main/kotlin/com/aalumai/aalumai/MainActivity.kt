package com.aalumai.aalumai

import android.content.Intent
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AlarmTriggerPlugin())
        flutterEngine.plugins.add(JarvisActionsPlugin())
        // A cold start triggered by the alarm notification (or its full-screen
        // intent) carries the alarm id; stash it for Dart to consume once its
        // navigator is ready.
        val openId = AlarmIntent.openAlarmId(intent)
        Log.i("AalumaiAlarm", "configureFlutterEngine action=${intent?.action} openId=$openId")
        openId?.let { AlarmTriggerPlugin.setPendingOpenAlarm(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // The activity was already running: hand the alarm id straight to Dart.
        val openId = AlarmIntent.openAlarmId(intent)
        Log.i("AalumaiAlarm", "onNewIntent action=${intent.action} openId=$openId")
        openId?.let { AlarmTriggerPlugin.deliverOpenAlarm(it) }
    }
}
