package com.example.status_downloader

import android.net.Uri
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.bumptech.glide.Glide
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.SimpleExoPlayer
import com.google.android.exoplayer2.ui.PlayerView
import android.widget.ImageView
import android.view.View

class PreviewActivity : AppCompatActivity() {
    private var player: SimpleExoPlayer? = null
    private var playerView: PlayerView? = null
    private var imageView: ImageView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_preview_native)

        playerView = findViewById(R.id.playerView)
        imageView = findViewById(R.id.imageViewPreview)

        val uriStr = intent.getStringExtra("uri") ?: return
        val uri = Uri.parse(uriStr)

        val mime = contentResolver.getType(uri) ?: ""
        if (mime.startsWith("video")) {
            imageView?.visibility = View.GONE
            playerView?.visibility = View.VISIBLE
            player = SimpleExoPlayer.Builder(this).build()
            playerView?.player = player
            val mediaItem = MediaItem.fromUri(uri)
            player?.setMediaItem(mediaItem)
            player?.prepare()
            player?.playWhenReady = true
        } else {
            playerView?.visibility = View.GONE
            imageView?.visibility = View.VISIBLE
            Glide.with(this).load(uri).into(imageView!!)
        }
    }

    override fun onStop() {
        super.onStop()
        player?.release()
        player = null
    }
}
