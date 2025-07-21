package com.example.video_player

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.video_player/audio_controls"
    private val EVENT_CHANNEL = "com.example.video_player/audio_events"

    companion object {
        var eventSink: EventChannel.EventSink? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAudio" -> {
                    val filePath = call.argument<String>("filePath")
                    val position = call.argument<Int>("position") ?: 0
                    val intent = Intent(this, AudioPlayerService::class.java).apply {
                        action = AudioPlayerService.ACTION_START
                        putExtra("filePath", filePath)
                        putExtra("position", position)
                    }
                    startForegroundService(intent)
                    result.success(null)
                }
                "pauseAudio" -> {
                    val intent = Intent(this, AudioPlayerService::class.java).apply {
                        action = AudioPlayerService.ACTION_PAUSE
                    }
                    startService(intent)
                    result.success(null)
                }
                "playAudio" -> {
                    val intent = Intent(this, AudioPlayerService::class.java).apply {
                        action = AudioPlayerService.ACTION_PLAY
                    }
                    startService(intent)
                    result.success(null)
                }
                "nextAudio" -> {
                    val intent = Intent(this, AudioPlayerService::class.java).apply {
                        action = AudioPlayerService.ACTION_NEXT
                    }
                    startService(intent)
                    result.success(null)
                }
                "seekTo" -> {
                    val position = call.argument<Int>("position") ?: 0
                    val intent = Intent(this, AudioPlayerService::class.java).apply {
                        action = AudioPlayerService.ACTION_SEEK
                        putExtra("position", position)
                    }
                    startService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }
}
