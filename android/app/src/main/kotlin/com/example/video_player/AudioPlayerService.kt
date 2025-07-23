package com.example.video_player

import android.app.*
import android.content.*
import android.media.MediaPlayer
import android.os.*
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import android.media.audiofx.Equalizer
import android.media.audiofx.BassBoost
import android.media.audiofx.Virtualizer
import android.media.audiofx.PresetReverb

class AudioPlayerService : Service() {
    companion object {
        const val CHANNEL_ID = "audio_playback_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_START = "ACTION_START"
        const val ACTION_PAUSE = "ACTION_PAUSE"
        const val ACTION_PLAY = "ACTION_PLAY"
        const val ACTION_NEXT = "ACTION_NEXT"
        const val ACTION_PREVIOUS = "ACTION_PREVIOUS"
        const val ACTION_SEEK = "ACTION_SEEK"
        const val ACTION_STOP = "ACTION_STOP"
        var instance: AudioPlayerService? = null
    }

    private var mediaPlayer: MediaPlayer? = null
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var reverb: PresetReverb? = null
    private var eqEnabled: Boolean = true
    private var eqPreset: Int = 0
    private var reverbPreset: Int = 0
    private var bassBoostStrength: Int = 0
    private var virtualizerStrength: Int = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val filePath = intent.getStringExtra("filePath")
                val position = intent.getIntExtra("position", 0)
                startAudio(filePath, position)
            }
            ACTION_PAUSE -> pauseAudio()
            ACTION_PLAY -> playAudio()
            ACTION_NEXT -> nextAudio()
            ACTION_PREVIOUS -> previousAudio()
            ACTION_SEEK -> {
                val position = intent.getIntExtra("position", 0)
                seekTo(position)
            }
            ACTION_STOP -> stopAudioExternally()
        }
        return START_STICKY
    }

    private fun sendPlaybackState(state: String) {
        val position = mediaPlayer?.currentPosition ?: 0
        val duration = mediaPlayer?.duration ?: 0
        val event = mapOf("state" to state, "position" to position, "duration" to duration)
        MainActivity.eventSink?.success(event)
    }

    private fun startAudio(filePath: String?, position: Int) {
        if (filePath == null) return
        mediaPlayer?.release()
        equalizer?.release()
        bassBoost?.release()
        virtualizer?.release()
        reverb?.release()
        mediaPlayer = MediaPlayer().apply {
            setDataSource(filePath)
            prepare()
            seekTo(position)
            start()
            setOnCompletionListener {
                sendPlaybackState("completed")
                stopSelf()
            }
        }
        // Initialize audio effects after MediaPlayer is prepared
        val sessionId = mediaPlayer!!.audioSessionId
        equalizer = Equalizer(0, sessionId)
        equalizer?.enabled = eqEnabled
        if (eqPreset > 0 && eqPreset < equalizer?.numberOfPresets ?: 0) {
            equalizer?.usePreset(eqPreset.toShort())
        }
        bassBoost = BassBoost(0, sessionId)
        bassBoost?.setStrength(bassBoostStrength.toShort())
        bassBoost?.enabled = true
        virtualizer = Virtualizer(0, sessionId)
        virtualizer?.setStrength(virtualizerStrength.toShort())
        virtualizer?.enabled = true
        reverb = PresetReverb(0, sessionId)
        reverb?.preset = reverbPreset.toShort()
        reverb?.enabled = true
        showNotification(isPlaying = true)
        sendPlaybackState("playing")
    }

    private fun pauseAudio() {
        mediaPlayer?.pause()
        showNotification(isPlaying = false)
        sendPlaybackState("paused")
    }

    private fun playAudio() {
        mediaPlayer?.start()
        showNotification(isPlaying = true)
        sendPlaybackState("playing")
    }

    private fun nextAudio() {
        // Implement logic to play next audio file if you have a playlist
        sendPlaybackState("next")
    }

    private fun previousAudio() {
        // Implement logic to play previous audio file if you have a playlist
        sendPlaybackState("previous")
    }

    private fun seekTo(position: Int) {
        mediaPlayer?.seekTo(position)
        sendPlaybackState(if (mediaPlayer?.isPlaying == true) "playing" else "paused")
    }

    private fun showNotification(isPlaying: Boolean) {
        val playPauseAction = if (isPlaying) {
            NotificationCompat.Action(
                android.R.drawable.ic_media_pause, "Pause",
                getPendingIntent(ACTION_PAUSE)
            )
        } else {
            NotificationCompat.Action(
                android.R.drawable.ic_media_play, "Play",
                getPendingIntent(ACTION_PLAY)
            )
        }
        val nextAction = NotificationCompat.Action(
            android.R.drawable.ic_media_next, "Next",
            getPendingIntent(ACTION_NEXT)
        )
        val prevAction = NotificationCompat.Action(
            android.R.drawable.ic_media_previous, "Previous",
            getPendingIntent(ACTION_PREVIOUS)
        )
        val stopAction = NotificationCompat.Action(
            android.R.drawable.ic_menu_close_clear_cancel, "Stop",
            getPendingIntent(ACTION_STOP)
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Audio Playing")
            .setContentText("Your audio is playing")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .addAction(prevAction)
            .addAction(playPauseAction)
            .addAction(nextAction)
            .addAction(stopAction)
            .setStyle(androidx.media.app.NotificationCompat.MediaStyle())
            .setOngoing(isPlaying)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun getPendingIntent(action: String): PendingIntent {
        val intent = Intent(this, AudioPlayerService::class.java).apply { this.action = action }
        return PendingIntent.getService(this, action.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Audio Playback",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        instance = null
        sendPlaybackState("stopped")
        mediaPlayer?.release()
        equalizer?.release()
        bassBoost?.release()
        virtualizer?.release()
        reverb?.release()
        super.onDestroy()
    }

    // Add a method to stop audio externally
    fun stopAudioExternally() {
        mediaPlayer?.stop()
        sendPlaybackState("stopped")
        stopSelf()
    }

    // Equalizer accessors for MethodChannel
    fun getEqualizerBands(): Int {
        return equalizer?.numberOfBands?.toInt() ?: 0
    }
    fun getEqualizerBandLevelRange(): ShortArray? {
        return equalizer?.bandLevelRange
    }
    fun getEqualizerBandLevel(band: Int): Short {
        return equalizer?.getBandLevel(band.toShort()) ?: 0
    }
    fun setEqualizerBandLevel(band: Int, level: Short) {
        equalizer?.setBandLevel(band.toShort(), level)
    }
    fun setEqualizerEnabled(enabled: Boolean) {
        eqEnabled = enabled
        equalizer?.enabled = enabled
    }
    fun getEqualizerEnabled(): Boolean {
        return eqEnabled
    }
    fun setEqualizerPreset(preset: Int) {
        eqPreset = preset
        if (equalizer != null && preset >= 0 && preset < (equalizer?.numberOfPresets ?: 0)) {
            equalizer?.usePreset(preset.toShort())
        }
    }
    fun getEqualizerPreset(): Int {
        return eqPreset
    }
    fun setReverbPreset(preset: Int) {
        reverbPreset = preset
        reverb?.preset = preset.toShort()
    }
    fun getReverbPreset(): Int {
        return reverbPreset
    }
    fun setBassBoostStrength(strength: Int) {
        bassBoostStrength = strength
        bassBoost?.setStrength(strength.toShort())
    }
    fun getBassBoostStrength(): Int {
        return bassBoostStrength
    }
    fun setVirtualizerStrength(strength: Int) {
        virtualizerStrength = strength
        virtualizer?.setStrength(strength.toShort())
    }
    fun getVirtualizerStrength(): Int {
        return virtualizerStrength
    }

    fun getBandLevelsForPreset(preset: Int): List<Int> {
        val eq = equalizer ?: return emptyList()
        if (preset < 0 || preset >= eq.numberOfPresets) return emptyList()
        eq.usePreset(preset.toShort())
        val levels = mutableListOf<Int>()
        for (i in 0 until eq.numberOfBands) {
            levels.add(eq.getBandLevel(i.toShort()).toInt())
        }
        // Restore current preset after reading
        if (eqPreset >= 0 && eqPreset < eq.numberOfPresets) {
            eq.usePreset(eqPreset.toShort())
        }
        return levels
    }
} 