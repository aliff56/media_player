package com.example.video_player

import android.app.*
import android.content.*
import android.media.MediaPlayer
import android.os.*
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class AudioPlayerService : Service() {
    companion object {
        const val CHANNEL_ID = "audio_playback_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_START = "ACTION_START"
        const val ACTION_PAUSE = "ACTION_PAUSE"
        const val ACTION_PLAY = "ACTION_PLAY"
        const val ACTION_NEXT = "ACTION_NEXT"
        const val ACTION_SEEK = "ACTION_SEEK"
    }

    private var mediaPlayer: MediaPlayer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
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
            ACTION_SEEK -> {
                val position = intent.getIntExtra("position", 0)
                seekTo(position)
            }
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

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Audio Playing")
            .setContentText("Your audio is playing")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .addAction(playPauseAction)
            .addAction(nextAction)
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
        sendPlaybackState("stopped")
        mediaPlayer?.release()
        super.onDestroy()
    }

    // Add a method to stop audio externally
    fun stopAudioExternally() {
        mediaPlayer?.stop()
        sendPlaybackState("stopped")
        stopSelf()
    }
} 