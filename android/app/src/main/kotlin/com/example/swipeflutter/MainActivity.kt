package com.example.swipeflutter

import android.content.ContentUris
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "swipegallery/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAllFilesAccess" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            Environment.isExternalStorageManager()
                        } else {
                            true
                        }
                        result.success(granted)
                    }
                    "moveToAlbum" -> {
                        val path = call.argument<String>("path") ?: ""
                        val ids = call.argument<List<String>>("ids") ?: emptyList()
                        result.success(moveToAlbum(ids, path))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Mueve imágenes de MediaStore a la carpeta [relativePath] (ej. Pictures/swipe-album).
     * Requiere "All files access" para no pedir permiso en cada operación.
     */
    private fun moveToAlbum(ids: List<String>, relativePath: String): Boolean {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
        }
        var moved = 0
        for (id in ids) {
            try {
                val uri = ContentUris.withAppendedId(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    id.toLong(),
                )
                moved += contentResolver.update(uri, values, null, null)
            } catch (_: Exception) {
                // Ignoramos ids inválidos.
            }
        }
        return moved > 0
    }
}
