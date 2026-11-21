package com.blackpiratex.quietpaper.watched

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/** Read-only Storage Access Framework bridge. Provider I/O never runs on the UI thread. */
class WatchedFolderBridge(private val activity: Activity) {
    companion object { const val PICK_TREE = 7142 }
    private val resolver get() = activity.contentResolver
    private val main = Handler(Looper.getMainLooper())
    private val executor = ThreadPoolExecutor(2, 2, 0, TimeUnit.MILLISECONDS, ArrayBlockingQueue<Runnable>(32))
    private val sessions = ConcurrentHashMap<String, Session>()
    private var picker: MethodChannel.Result? = null
    private var channel: MethodChannel? = null
    @Volatile private var foreground = false
    @Volatile private var closed = false
    private data class Session(val tree: Uri, val rootId: String) {
        @Volatile var ready = false
        @Volatile var stopped = false
        val known = ConcurrentHashMap.newKeySet<String>().apply { add(rootId) }
        val directories = ConcurrentHashMap.newKeySet<String>().apply { add(rootId) }
        val signals = ConcurrentHashMap.newKeySet<CancellationSignal>()
        fun cancel() { signals.toList().forEach { it.cancel() } }
    }
    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "com.blackpiratex.quietpaper/watched_folders").also { it.setMethodCallHandler(::handle) }
    }
    fun setForeground(value: Boolean) {
        foreground = value
        if (!value) sessions.values.forEach { it.cancel() }
    }
    private fun tree(root: String): Uri {
        val uri = Uri.parse(root)
        if (uri.scheme != "content" || uri.authority.isNullOrEmpty() || !DocumentsContract.isTreeUri(uri)) {
            throw WatchedReadException("invalid_tree")
        }
        val canonical = DocumentsContract.buildTreeDocumentUri(uri.authority, DocumentsContract.getTreeDocumentId(uri))
        if (resolver.persistedUriPermissions.none { it.isReadPermission && it.uri == canonical }) throw WatchedReadException("permission_needed")
        return canonical
    }
    private fun identity(tree: Uri) = "saf:${tree.authority}:${DocumentsContract.getTreeDocumentId(tree)}"
    private fun uri(session: Session, id: String): Uri {
        if (!session.known.contains(id)) throw WatchedReadException("unsafe_document")
        return DocumentsContract.buildDocumentUriUsingTree(session.tree, id)
    }
    private fun check(session: Session) {
        if (closed || session.stopped || !session.ready || !foreground) throw WatchedReadException("locked")
    }
    private fun <T> signal(session: Session, action: (CancellationSignal) -> T): T {
        check(session)
        val signal = CancellationSignal()
        session.signals.add(signal)
        return try { check(session); action(signal) } finally { session.signals.remove(signal) }
    }
    private val projection = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE,
        DocumentsContract.Document.COLUMN_SIZE, DocumentsContract.Document.COLUMN_LAST_MODIFIED, DocumentsContract.Document.COLUMN_FLAGS)
    private fun document(cursor: android.database.Cursor): WatchedDocument {
        fun string(name: String): String = cursor.getColumnIndex(name).let { if (it < 0 || cursor.isNull(it)) throw WatchedReadException("provider_metadata_missing") else cursor.getString(it) }
        fun number(name: String): Long? = cursor.getColumnIndex(name).let { if (it < 0 || cursor.isNull(it)) null else cursor.getLong(it).takeIf { value -> value >= 0 } }
        val flags = number(DocumentsContract.Document.COLUMN_FLAGS) ?: 0
        val id = string(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
        if (id.isEmpty() || id.length > 8192) throw WatchedReadException("provider_metadata_invalid")
        return WatchedDocument(id, string(DocumentsContract.Document.COLUMN_DISPLAY_NAME), string(DocumentsContract.Document.COLUMN_MIME_TYPE),
            number(DocumentsContract.Document.COLUMN_SIZE), number(DocumentsContract.Document.COLUMN_LAST_MODIFIED),
            flags and DocumentsContract.Document.FLAG_PARTIAL.toLong() != 0L,
            flags and DocumentsContract.Document.FLAG_VIRTUAL_DOCUMENT.toLong() != 0L)
    }
    private fun stat(session: Session, id: String): WatchedDocument = signal(session) { cancel ->
        resolver.query(uri(session, id), projection, null, null, null, cancel)?.use { cursor ->
            if (!cursor.moveToFirst()) throw WatchedReadException("source_unreadable")
            document(cursor).also { if (it.id != id) throw WatchedReadException("unsafe_document") }
        } ?: throw WatchedReadException("source_unreadable")
    }
    private fun inspect(root: String): Map<String, Any?> {
        val tree = tree(root)
        val id = DocumentsContract.getTreeDocumentId(tree)
        val docUri = DocumentsContract.buildDocumentUriUsingTree(tree, id)
        val doc = resolver.query(docUri, projection, null, null, null)?.use {
            if (!it.moveToFirst()) throw WatchedReadException("root_unavailable")
            document(it)
        } ?: throw WatchedReadException("root_unavailable")
        if (!doc.directory || doc.id != id) throw WatchedReadException("invalid_tree")
        return mapOf("root" to tree.toString(), "identity" to identity(tree), "name" to doc.name)
    }
    private fun children(session: Session, parent: String, offset: Int): Map<String, Any?> = signal(session) { cancel ->
        if (offset < 0 || offset > 100000 || !session.directories.contains(parent)) throw WatchedReadException("unsafe_document")
        val target = DocumentsContract.buildChildDocumentsUriUsingTree(session.tree, parent)
        resolver.query(target, projection, null, null, null, cancel)?.use { cursor ->
            if (cursor.extras.getBoolean(DocumentsContract.EXTRA_LOADING, false)) throw WatchedReadException("provider_loading")
            val result = mutableListOf<Map<String, Any?>>()
            var more = cursor.moveToPosition(offset)
            while (more && result.size < 64) {
                check(session)
                val doc = document(cursor)
                if (session.known.size >= 100001 && !session.known.contains(doc.id)) throw WatchedReadException("scan_limit")
                session.known.add(doc.id)
                if (doc.directory) session.directories.add(doc.id)
                result.add(doc.map())
                more = cursor.moveToNext()
            }
            mapOf("documents" to result, "nextOffset" to if (more) offset + result.size else null)
        } ?: throw WatchedReadException("source_unreadable")
    }
    private fun read(session: Session, id: String, limit: Int, bytes: Boolean): WatchedRead {
        val signals = mutableListOf<CancellationSignal>()
        val access = object : WatchedDocumentAccess {
            override fun stat(id: String) = stat(session, id)
            override fun open(id: String): InputStream {
                check(session)
                val cancel = CancellationSignal()
                signals.add(cancel); session.signals.add(cancel)
                check(session)
                val descriptor = resolver.openAssetFileDescriptor(uri(session, id), "r", cancel)
                    ?: throw WatchedReadException("source_unreadable")
                return try { descriptor.createInputStream() }
                catch (error: Exception) { descriptor.close(); throw error }
            }
        }
        return try {
            WatchedDocumentReader.read(access, id, limit, bytes) { closed || session.stopped || !session.ready || !foreground || signals.any { it.isCanceled } }
        } finally { signals.forEach { session.signals.remove(it) } }
    }
    private fun related(session: Session, source: List<String>, target: String): ByteArray {
        if (source.size > 65 || source.isEmpty() || source.any { !WatchedDocumentReader.safeName(it) } ||
            target.length > 8192 || target.startsWith('/') || ':' in target || '\\' in target) throw WatchedReadException("unsafe_image_path")
        val parts = target.split('/')
        fun normalize(path: List<String>): List<String>? {
            val result = mutableListOf<String>()
            for (part in path) when (part) {
                "", "." -> Unit
                ".." -> if (result.isEmpty()) return null else result.removeAt(result.lastIndex)
                else -> if (WatchedDocumentReader.safeName(part)) result.add(part) else return null
            }
            return result.takeIf { it.size in 1..65 }
        }
        val parent = source.dropLast(1)
        val paths = mutableListOf(parent + parts, parts)
        for (folder in listOf("attachments", "_resources", "assets", "images", "media", "files", "img", "photos")) {
            paths.add(parent + folder + parts); paths.add(parent + folder + parts.last())
            paths.add(listOf(folder) + parts); paths.add(listOf(folder, parts.last()))
        }
        var pageReads = 0
        for (path in paths.mapNotNull(::normalize).distinct()) {
            if (path.last().substringAfterLast('.').lowercase(java.util.Locale.ROOT) !in listOf("png", "jpg", "jpeg", "webp")) throw WatchedReadException("unsupported_image")
            var id = session.rootId
            var found = true
            for ((index, part) in path.withIndex()) {
                val matches = mutableListOf<String>()
                var offset: Int? = 0
                do {
                    if (++pageReads > 512) throw WatchedReadException("image_lookup_limit")
                    val page = children(session, id, offset!!)
                    @Suppress("UNCHECKED_CAST")
                    for (doc in page["documents"] as List<Map<String, Any?>>) {
                        if (doc["name"] == part && (index == path.lastIndex || doc["mime"] == "vnd.android.document/directory")) matches.add(doc["id"] as String)
                    }
                    offset = page["nextOffset"] as Int?
                } while (offset != null)
                if (matches.size != 1) { found = false; break }
                id = matches.single()
            }
            if (found) return read(session, id, 10_000_000, true).bytes!!
        }
        throw WatchedReadException("missing_or_unsafe_image")
    }
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (closed) { result.error("engine_stopped", "Folder access is closed.", null); return }
        fun string(key: String) = call.argument<String>(key) ?: throw WatchedReadException("invalid_argument")
        try {
            when (call.method) {
                "available" -> { result.success(null); return }
                "chooseFolder" -> {
                    if (picker != null) { result.error("picker_busy", "Finish choosing a folder first.", null); return }
                    picker = result
                    try { activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                    }, PICK_TREE) } catch (_: Exception) { picker = null; result.error("picker_unavailable", "The folder picker is unavailable.", null) }
                    return
                }
                "ready" -> {
                    val session = sessions[string("session")] ?: throw WatchedReadException("engine_stopped")
                    session.ready = call.argument<Boolean>("ready") == true
                    if (!session.ready) session.cancel()
                    result.success(null); return
                }
                "stop" -> { sessions.remove(string("session"))?.let { it.stopped = true; it.cancel() }; result.success(null); return }
                "open" -> {
                    val tree = tree(string("root"))
                    val id = call.argument<String>("id")
                    val intent = if (id == null) Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply { putExtra(DocumentsContract.EXTRA_INITIAL_URI, tree) }
                        else Intent(Intent.ACTION_VIEW).apply { data = DocumentsContract.buildDocumentUriUsingTree(tree, id); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION) }
                    activity.startActivity(intent); result.success(null); return
                }
            }
            val supported = setOf("inspect", "start", "children", "stat", "read", "relatedImage")
            if (call.method !in supported) { result.notImplemented(); return }
            executor.execute {
                try {
                    val value: Any? = when (call.method) {
                        "inspect" -> inspect(string("root"))
                        "start" -> {
                            val root = string("root"); inspect(root)
                            val tree = tree(root)
                            if (identity(tree) != string("identity")) throw WatchedReadException("root_identity_changed")
                            if (closed) throw WatchedReadException("engine_stopped")
                            val session = Session(tree, DocumentsContract.getTreeDocumentId(tree))
                            if (sessions.putIfAbsent(string("session"), session) != null) throw WatchedReadException("session_exists")
                            session.rootId
                        }
                        else -> {
                            val session = sessions[string("session")] ?: throw WatchedReadException("engine_stopped")
                            check(session)
                            when (call.method) {
                                "children" -> children(session, string("parent"), call.argument<Int>("offset") ?: 0)
                                "stat" -> {
                                    val ids = call.argument<List<String>>("ids") ?: throw WatchedReadException("invalid_argument")
                                    if (ids.size > 8) throw WatchedReadException("invalid_argument")
                                    ids.map { stat(session, it).map() }
                                }
                                "read" -> read(session, string("id"), call.argument<Int>("limit") ?: 0, call.argument<Boolean>("bytes") == true).map()
                                else -> related(session, call.argument<List<String>>("source") ?: emptyList(), string("target"))
                            }
                        }
                    }
                    main.post { if (!closed) result.success(value) else result.error("engine_stopped", "Folder access is closed.", null) }
                } catch (e: Exception) {
                    val code = when (e) { is WatchedReadException -> e.code; is SecurityException -> "permission_needed"; is android.os.OperationCanceledException -> "locked"; else -> "provider_io" }
                    main.post { result.error(code, "Could not read the selected folder. Code: $code", null) }
                }
            }
        } catch (_: RejectedExecutionException) { result.error("busy", "Folder reader is busy.", null) }
        catch (e: Exception) { result.error((e as? WatchedReadException)?.code ?: "provider_io", "Could not access the selected folder.", null) }
    }
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_TREE) return false
        val result = picker ?: return true
        picker = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) { result.success(null); return true }
        try {
            val uri = data.data!!
            if (data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION == 0 || !DocumentsContract.isTreeUri(uri)) throw WatchedReadException("permission_needed")
            resolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            result.success(tree(uri.toString()).toString())
        } catch (_: Exception) { result.error("permission_needed", "Persistent read access was not granted. Choose the folder again.", null) }
        return true
    }
    fun close() {
        closed = true; foreground = false
        picker?.error("picker_cancelled", "Folder selection was interrupted.", null); picker = null
        sessions.values.forEach { it.stopped = true; it.cancel() }; sessions.clear()
        channel?.setMethodCallHandler(null); executor.shutdownNow()
    }
}
