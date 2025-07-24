package com.example.video_player

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.os.Build
import android.os.Bundle
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.video_player/audio_controls"
    private val EVENT_CHANNEL = "com.example.video_player/audio_events"

    companion object {
        var eventSink: EventChannel.EventSink? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Request notification permission on Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
            }
        }
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
                    // Use startService if service is already running, otherwise startForegroundService
                    if (AudioPlayerService.instance != null) {
                        startService(intent)
                    } else {
                    startForegroundService(intent)
                    }
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
                "previousAudio" -> {
                    val intent = Intent(this, AudioPlayerService::class.java).apply {
                        action = AudioPlayerService.ACTION_PREVIOUS
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
                "getEqualizerBands" -> {
                    val service = getAudioPlayerServiceInstance()
                    result.success(service?.getEqualizerBands() ?: 0)
                }
                "getEqualizerBandLevelRange" -> {
                    val service = getAudioPlayerServiceInstance()
                    val range = service?.getEqualizerBandLevelRange()
                    if (range != null) {
                        result.success(listOf(range[0].toInt(), range[1].toInt()))
                    } else {
                        result.success(listOf(0, 0))
                    }
                }
                "getEqualizerBandLevel" -> {
                    val band = call.argument<Int>("band") ?: 0
                    val service = getAudioPlayerServiceInstance()
                    result.success(service?.getEqualizerBandLevel(band)?.toInt() ?: 0)
                }
                "setEqualizerBandLevel" -> {
                    val band = call.argument<Int>("band") ?: 0
                    val level = call.argument<Int>("level")?.toShort() ?: 0
                    val service = getAudioPlayerServiceInstance()
                    service?.setEqualizerBandLevel(band, level)
                    result.success(null)
                }
                "setEqualizerEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val service = getAudioPlayerServiceInstance()
                    service?.setEqualizerEnabled(enabled)
                    result.success(null)
                }
                "getEqualizerEnabled" -> {
                    val service = getAudioPlayerServiceInstance()
                    result.success(service?.getEqualizerEnabled() ?: true)
                }
                "setEqualizerPreset" -> {
                    val preset = call.argument<Int>("preset") ?: 0
                    val service = getAudioPlayerServiceInstance()
                    service?.setEqualizerPreset(preset)
                    result.success(null)
                }
                "getEqualizerPreset" -> {
                    val service = getAudioPlayerServiceInstance()
                    result.success(service?.getEqualizerPreset() ?: 0)
                }
                "setReverbPreset" -> {
                    val preset = call.argument<Int>("preset") ?: 0
                    val service = getAudioPlayerServiceInstance()
                    service?.setReverbPreset(preset)
                    result.success(null)
                }
                "getReverbPreset" -> {
                    val service = getAudioPlayerServiceInstance()
                    result.success(service?.getReverbPreset() ?: 0)
                }
                "setBassBoostStrength" -> {
                    val strength = call.argument<Int>("strength") ?: 0
                    val service = getAudioPlayerServiceInstance()
                    service?.setBassBoostStrength(strength)
                    result.success(null)
                }
                "getBassBoostStrength" -> {
                    val service = getAudioPlayerServiceInstance()
                    result.success(service?.getBassBoostStrength() ?: 0)
                }
                "setVirtualizerStrength" -> {
                    val strength = call.argument<Int>("strength") ?: 0
                    val service = getAudioPlayerServiceInstance()
                    service?.setVirtualizerStrength(strength)
                    result.success(null)
                }
                "getVirtualizerStrength" -> {
                    val service = getAudioPlayerServiceInstance()
                    result.success(service?.getVirtualizerStrength() ?: 0)
                }
                "getBandLevelsForPreset" -> {
                    val preset = call.argument<Int>("preset") ?: 0
                    val service = getAudioPlayerServiceInstance()
                    val levels = service?.getBandLevelsForPreset(preset) ?: listOf<Int>()
                    result.success(levels)
                }
                "setPlaybackSpeed" -> {
                    val speed = call.argument<Double>("speed") ?: 1.0
                    val intent = Intent(this, AudioPlayerService::class.java).apply {
                        action = AudioPlayerService.ACTION_SET_SPEED
                        putExtra("speed", speed.toFloat())
                    }
                    startService(intent)
                    result.success(null)
                }
                "getPlaybackSpeed" -> {
                    val service = getAudioPlayerServiceInstance()
                    result.success(service?.getPlaybackSpeed()?.toDouble() ?: 1.0)
                }
                "setAsRingtone" -> {
                    val path = call.argument<String>("filePath")
                    if (path != null) {
                        val success = AudioPlayerService.setAsRingtone(this, path)
                        result.success(success)
                    } else {
                        result.error("ARG", "filePath missing", null)
                    }
                }
                "playNextAudio" -> {
                    val filePath = call.argument<String>("filePath")
                    val position = call.argument<Int>("position") ?: 0
                    val intent = Intent(this, AudioPlayerService::class.java).apply {
                        action = AudioPlayerService.ACTION_START
                        putExtra("filePath", filePath)
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

    // Helper to get the running AudioPlayerService instance
    private fun getAudioPlayerServiceInstance(): AudioPlayerService? {
        return AudioPlayerService.instance
    }
}
