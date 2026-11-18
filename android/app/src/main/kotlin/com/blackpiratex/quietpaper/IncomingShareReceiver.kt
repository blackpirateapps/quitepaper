package com.blackpiratex.quietpaper

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Parcelable
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/** Bounded native normalization for the existing Dart ShareIntentHandler.
 * Streams content URIs while temporary grants are live; never guesses paths.
 * Private staging is acknowledged/deleted after review, including cancellation.
 */
class IncomingShareReceiver(private val activity: Activity) {
    private val executor = Executors.newSingleThreadExecutor()
    private val pending = linkedMapOf<String, Map<String, Any?>>()
    private val folders = linkedMapOf<String, File>()
    private val cancelled = mutableSetOf<String>()
    private var channel: MethodChannel? = null
    private val root by lazy { File(activity.cacheDir, "incoming-email").apply { mkdirs(); privateAccess(this) } }

    fun attach(messenger: BinaryMessenger) {
        // No restart may silently restore a plaintext preview or create a note.
        root.listFiles()?.forEach { it.deleteRecursively() }
        channel = MethodChannel(messenger, "com.blackpiratex.quietpaper/incoming_share").also { method ->
            method.setMethodCallHandler { call, result ->
                when (call.method) {
                    "drain" -> result.success(pending.values.toList())
                    "acknowledge" -> { acknowledge(call.argument<String>("id")); result.success(null) }
                    "clear" -> { folders.keys.toList().forEach { acknowledge(it) }; result.success(null) }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun receive(intent: Intent?) {
        if (intent == null || intent.action !in listOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE, Intent.ACTION_VIEW)) return
        val id = UUID.randomUUID().toString()
        if (folders.size >= 100) { publishError(id, "The share queue is full. Finish the current import and share again."); return }
        val uris = linkedSetOf<Uri>()
        if (intent.action == Intent.ACTION_VIEW) intent.data?.let { if (it.scheme in listOf("content", "file")) uris.add(it) }
        if (intent.action == Intent.ACTION_SEND) stream(intent)?.let { uris.add(it) }
        if (intent.action == Intent.ACTION_SEND_MULTIPLE) streams(intent)?.let { uris.addAll(it) }
        intent.clipData?.let { clip ->
            if (clip.itemCount > 100) { publishError(id, "Select at most 100 shared files."); return }
            for (i in 0 until clip.itemCount) clip.getItemAt(i).uri?.let { uris.add(it) }
        }
        if (uris.size > 100) { publishError(id, "Select at most 100 shared files."); return }
        val rawText = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        val html = intent.getStringExtra(Intent.EXTRA_HTML_TEXT)
        val text = rawText ?: html ?: (if (uris.isEmpty() && intent.data?.scheme in listOf("http", "https")) intent.dataString else null) ?: if (uris.isEmpty() && (intent.clipData?.itemCount ?: 0) > 0) intent.clipData?.getItemAt(0)?.text?.toString() else null
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.take(65536)
        if (text != null && text.length > 500000) { publishError(id, "Shared text exceeds the 500,000 character capture limit. Export the email as .eml instead."); return }
        val declared = intent.type
        val folder = File(root, id).apply { mkdirs(); privateAccess(this) }
        folders[id] = folder
        executor.execute {
            val files = mutableListOf<Map<String, Any?>>()
            for ((index, uri) in uris.withIndex()) {
                if (Thread.currentThread().isInterrupted) break
                var name: String? = null
                var mime: String? = declared
                try {
                    if (uri.scheme !in listOf("content", "file")) throw IllegalArgumentException()
                    if (uri.scheme == "content") {
                        mime = activity.contentResolver.getType(uri) ?: declared
                        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                            if (cursor.moveToFirst()) {
                                val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                                if (nameColumn >= 0 && !cursor.isNull(nameColumn)) name = cursor.getString(nameColumn)?.take(255)
                                val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                                if (sizeColumn >= 0 && !cursor.isNull(sizeColumn) && cursor.getLong(sizeColumn) > MAX_BYTES) throw IllegalArgumentException()
                            }
                        }
                    } else name = uri.lastPathSegment?.take(255)
                    // The provider-supplied name never controls a filesystem path.
                    val staged = File(folder, "$index.source")
                    val input = if (uri.scheme == "content") activity.contentResolver.openInputStream(uri) else File(uri.path ?: "").inputStream()
                    if (input == null) throw IllegalArgumentException()
                    input.use { source ->
                        staged.outputStream().use { target ->
                            privateAccess(staged)
                            val buffer = ByteArray(64 * 1024)
                            var total = 0L
                            while (true) {
                                if (Thread.currentThread().isInterrupted) throw InterruptedException()
                                val count = source.read(buffer)
                                if (count < 0) break
                                total += count
                                if (total > MAX_BYTES) throw IllegalArgumentException()
                                target.write(buffer, 0, count)
                            }
                        }
                    }
                    files.add(mapOf("path" to staged.path, "name" to (name ?: "shared-file"), "mimeType" to mime))
                } catch (_: Exception) {
                    File(folder, "$index.source").delete()
                    files.add(mapOf("error" to "Could not read shared file ${index + 1}. Check access and the 50 MiB limit."))
                }
            }
            activity.runOnUiThread {
                if (cancelled.remove(id)) { folder.deleteRecursively(); return@runOnUiThread }
                val data = mapOf("id" to id, "files" to files, "text" to text, "subject" to subject, "isHtml" to (rawText == null && html != null || declared == "text/html"))
                pending[id] = data
                channel?.invokeMethod("onIncomingShare", data)
            }
        }
    }

    private fun publishError(id: String, message: String) {
        val data = mapOf("id" to id, "error" to message)
        pending[id] = data
        channel?.invokeMethod("onIncomingShare", data)
    }
    private fun acknowledge(id: String?) {
        if (id == null) return
        pending.remove(id)
        cancelled.add(id)
        // Deletion is serialized after any in-flight copy.
        folders.remove(id)?.let { folder -> executor.execute { folder.deleteRecursively() } }
        if (cancelled.size > 256) cancelled.remove(cancelled.first())
    }
    fun close() { channel?.setMethodCallHandler(null); executor.shutdownNow() }
    private fun privateAccess(file: File) {
        file.setReadable(false, false); file.setWritable(false, false); file.setExecutable(false, false)
        file.setReadable(true, true); file.setWritable(true, true)
        if (file.isDirectory) file.setExecutable(true, true)
    }
    @Suppress("DEPRECATION")
    private fun stream(intent: Intent): Uri? = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java) else intent.getParcelableExtra<Parcelable>(Intent.EXTRA_STREAM) as? Uri
    @Suppress("DEPRECATION")
    private fun streams(intent: Intent): ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java) else intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
    companion object {
        private const val MAX_BYTES = 50L * 1024 * 1024
        fun pluginIntent(intent: Intent): Intent {
            if (intent.action !in listOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE, Intent.ACTION_VIEW)) return intent
            // The installed plugin otherwise makes another unbounded plaintext
            // copy and emits duplicate initial/stream deliveries. Android goes
            // through this normalizer and the existing Dart handler exactly once.
            return Intent(intent).apply { action = Intent.ACTION_MAIN; type = null; data = null; clipData = null; replaceExtras(null as android.os.Bundle?) }
        }
    }
}
