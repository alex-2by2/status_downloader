package com.example.status_downloader

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import androidx.annotation.NonNull
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.statusdownloader/saf"
    private val OPEN_TREE_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDocumentTree" -> {
                    pendingResult = result
                    openDocumentTree()
                }
                "listFilesInTree" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr == null) result.error("ARG_ERROR", "uri is required", null)
                    else result.success(listFilesInTree(Uri.parse(uriStr)))
                }
                "takePersistablePermission" -> {
                    val uriStr = call.argument<String>("uri")
                    val mode = call.argument<Int>("mode") ?: Intent.FLAG_GRANT_READ_URI_PERMISSION
                    if (uriStr == null) result.error("ARG_ERROR", "uri required", null)
                    else {
                        try {
                            val uri = Uri.parse(uriStr)
                            contentResolver.takePersistableUriPermission(uri, mode)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("PERM_ERROR", e.message, null)
                        }
                    }
                }
                "deleteDocument" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr == null) result.error("ARG_ERROR", "uri required", null)
                    else {
                        try {
                            val uri = Uri.parse(uriStr)
                            val doc = DocumentFile.fromSingleUri(this, uri)
                            val ok = doc?.delete() ?: false
                            result.success(ok)
                        } catch (e: Exception) {
                            result.error("DEL_ERROR", e.message, null)
                        }
                    }
                }
                "copyDocumentsToPictures" -> {
                    val uris = call.argument<List<String>>("uris") ?: listOf()
                    val saved = mutableListOf<String>()
                    try {
                        for (s in uris) {
                            val name = copyDocumentToPictures(Uri.parse(s))
                            if (name != null) saved.add(name)
                        }
                        result.success(saved)
                    } catch (e: Exception) {
                        result.error("COPY_ERROR", e.message, null)
                    }
                }
                "openDocument" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr == null) result.error("ARG_ERROR", "uri required", null)
                    else {
                        try {
                            openDocument(Uri.parse(uriStr))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_ERROR", e.message, null)
                        }
                    }
                }
                "openDocumentInApp" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr == null) result.error("ARG_ERROR", "uri required", null)
                    else {
                        try {
                            val intent = Intent(this, PreviewActivity::class.java)
                            intent.putExtra("uri", uriStr)
                            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_IN_APP_ERROR", e.message, null)
                        }
                    }
                }
                "readFileBytes" -> {
                    val uriStr = call.argument<String>("uri")
                    val maxBytes = call.argument<Int>("maxBytes") ?: -1
                    if (uriStr == null) result.error("ARG_ERROR", "uri required", null)
                    else {
                        try {
                            val bytes = readFileBytes(Uri.parse(uriStr), maxBytes)
                            result.success(bytes?.toList())
                        } catch (e: Exception) {
                            result.error("READ_ERROR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openDocumentTree() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        startActivityForResult(intent, OPEN_TREE_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OPEN_TREE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val treeUri = data.data
                if (treeUri != null) {
                    val takeFlags = (data.flags
                            and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
                    contentResolver.takePersistableUriPermission(treeUri, takeFlags)
                    pendingResult?.success(treeUri.toString())
                    pendingResult = null
                } else {
                    pendingResult?.error("PICK_ERROR", "No uri returned", null)
                    pendingResult = null
                }
            } else {
                pendingResult?.error("PICK_CANCEL", "User cancelled", null)
                pendingResult = null
            }
        }
    }

    private fun listFilesInTree(treeUri: Uri): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val pickedDir = DocumentFile.fromTreeUri(this, treeUri)
        if (pickedDir == null || !pickedDir.exists()) return results

        val children = pickedDir.listFiles()
        for (f in children) {
            val map = mutableMapOf<String, Any?>()
            map["name"] = f.name
            map["uri"] = f.uri.toString()
            map["isDirectory"] = f.isDirectory
            map["mime"] = f.type
            map["lastModified"] = f.lastModified()
            map["size"] = f.length()
            results.add(map)
        }
        return results
    }

    private fun copyDocumentToPictures(docUri: Uri): String? {
        val doc = DocumentFile.fromSingleUri(this, docUri) ?: return null
        val input = contentResolver.openInputStream(docUri) ?: return null
        val filename = doc.name ?: "status_${System.currentTimeMillis()}"
        val mime = doc.type ?: "image/jpeg"

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/WhatsAppStatusDownloader")
            }
        }

        val collection = if (mime.startsWith("video")) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }

        val outUri = contentResolver.insert(collection, values) ?: return null
        val out = contentResolver.openOutputStream(outUri) ?: return null

        input.use { inp ->
            out.use { outp ->
                inp.copyTo(outp)
            }
        }
        return filename
    }

    private fun openDocument(docUri: Uri) {
        val mime = contentResolver.getType(docUri) ?: "*/*"
        val intent = Intent(Intent.ACTION_VIEW)
        intent.setDataAndType(docUri, mime)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        startActivity(intent)
    }

    private fun readFileBytes(docUri: Uri, maxBytes: Int = -1): ByteArray? {
        val input = contentResolver.openInputStream(docUri) ?: return null
        val buffer = ByteArrayOutputStream()
        val tmp = ByteArray(8 * 1024)
        var read: Int
        var remaining = if (maxBytes > 0) maxBytes else Int.MAX_VALUE
        input.use { inp ->
            while (true) {
                read = inp.read(tmp)
                if (read <= 0) break
                val toWrite = if (read > remaining) remaining else read
                buffer.write(tmp, 0, toWrite)
                remaining -= toWrite
                if (remaining <= 0) break
            }
        }
        return buffer.toByteArray()
    }
}
