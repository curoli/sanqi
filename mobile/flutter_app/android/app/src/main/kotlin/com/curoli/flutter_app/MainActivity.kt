package com.curoli.flutter_app

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var player: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.curoli.sanqi/move_feedback")
            .setMethodCallHandler { call, result ->
                val clip = when (call.method) {
                    "move" -> "move.wav"
                    "gameOver" -> "game_over.wav"
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                try {
                    playFeedback(clip)
                    result.success(null)
                } catch (error: Exception) {
                    releasePlayer()
                    result.error("playback", error.message, null)
                }
            }
    }

    private fun playFeedback(clip: String) {
        releasePlayer()
        val asset = FlutterInjector.instance().flutterLoader()
            .getLookupKeyForAsset("assets/sounds/$clip")
        val next = MediaPlayer()
        player = next
        next.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        assets.openFd(asset).use { next.setDataSource(it) }
        next.setOnPreparedListener { if (player === it) it.start() }
        next.setOnCompletionListener { if (player === it) releasePlayer() }
        next.setOnErrorListener { failed, _, _ ->
            if (player === failed) releasePlayer()
            true
        }
        next.prepareAsync()
    }

    private fun releasePlayer() {
        val previous = player
        player = null
        previous?.release()
    }

    override fun onStop() {
        releasePlayer()
        super.onStop()
    }
}
