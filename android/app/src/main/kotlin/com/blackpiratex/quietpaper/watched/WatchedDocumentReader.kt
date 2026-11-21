package com.blackpiratex.quietpaper.watched

import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.security.MessageDigest
import java.util.Locale

/** Pure bounded reader; SAF metadata and streams are injected by the Android host. */
data class WatchedDocument(
    val id: String, val name: String, val mime: String, val size: Long?, val modified: Long?,
    val partial: Boolean = false, val virtual: Boolean = false,
) {
    val directory get() = mime == "vnd.android.document/directory"
    val fingerprint: String get() = digest(
        listOf(id, name, mime, size?.toString() ?: "?", modified?.toString() ?: "?", partial.toString(), virtual.toString())
            .joinToString("\u0000").toByteArray(Charsets.UTF_8)
    )
    fun map(): Map<String, Any?> = mapOf("id" to id, "name" to name, "mime" to mime,
        "size" to size, "modified" to modified, "partial" to partial, "virtual" to virtual,
        "fingerprint" to fingerprint)
}
class WatchedReadException(val code: String) : Exception(code)
interface WatchedDocumentAccess {
    fun stat(id: String): WatchedDocument
    fun open(id: String): InputStream
}
data class WatchedRead(val hash: String, val revision: String, val fingerprint: String, val size: Int, val bytes: ByteArray?) {
    fun map(): Map<String, Any?> = mapOf("sha256" to hash, "revision" to revision,
        "fingerprint" to fingerprint, "size" to size, "bytes" to bytes)
}
internal fun digest(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(bytes).hex()
private fun ByteArray.hex() = joinToString("") { "%02x".format(it) }

object WatchedDocumentReader {
    fun limit(name: String): Int? = when (name.substringAfterLast('.', "").lowercase(Locale.ROOT)) {
        "eml" -> 50 * 1024 * 1024
        "md", "markdown", "txt" -> 10 * 1024 * 1024
        "pdf", "png", "jpg", "jpeg", "webp" -> 10_000_000
        else -> null
    }
    fun safeName(name: String) = name.isNotEmpty() && name.length <= 255 && !name.startsWith('.') &&
        name.none { it == '/' || it == '\\' || it.code < 32 || it.code == 127 }
    private fun validHeader(name: String, bytes: ByteArray): Boolean {
        fun prefix(vararg values: Int) = bytes.size >= values.size && values.indices.all { (bytes[it].toInt() and 255) == values[it] }
        return when (name.substringAfterLast('.').lowercase(Locale.ROOT)) {
            "pdf" -> prefix(37, 80, 68, 70, 45)
            "png" -> prefix(137, 80, 78, 71, 13, 10, 26, 10)
            "jpg", "jpeg" -> prefix(255, 216, 255)
            "webp" -> bytes.size >= 12 && String(bytes.copyOfRange(0, 4), Charsets.US_ASCII) == "RIFF" &&
                String(bytes.copyOfRange(8, 12), Charsets.US_ASCII) == "WEBP"
            else -> true
        }
    }
    fun read(access: WatchedDocumentAccess, id: String, maximum: Int, keepBytes: Boolean, cancelled: () -> Boolean): WatchedRead {
        fun check() { if (cancelled() || Thread.currentThread().isInterrupted) throw WatchedReadException("locked") }
        check()
        val before = access.stat(id)
        val policyLimit = limit(before.name) ?: throw WatchedReadException("unsupported_or_oversized")
        val bound = minOf(maximum, policyLimit)
        if (bound <= 0 || before.directory || !safeName(before.name) || before.partial || before.virtual ||
            (before.size != null && before.size > bound)) throw WatchedReadException("unsupported_or_oversized")
        val hash = MessageDigest.getInstance("SHA-256")
        val output = if (keepBytes) ByteArrayOutputStream(minOf(bound, 64 * 1024)) else null
        val header = ByteArrayOutputStream(12)
        var total = 0
        access.open(id).use { input ->
            val buffer = ByteArray(64 * 1024)
            var emptyReads = 0
            while (true) {
                check()
                val count = input.read(buffer, 0, minOf(buffer.size, bound - total + 1))
                if (count < 0) break
                if (count == 0) {
                    if (++emptyReads > 8) throw WatchedReadException("source_unreadable")
                    continue
                }
                emptyReads = 0
                total += count
                if (total > bound) throw WatchedReadException("unsupported_or_oversized")
                hash.update(buffer, 0, count)
                output?.write(buffer, 0, count)
                if (header.size() < 12) header.write(buffer, 0, minOf(count, 12 - header.size()))
            }
        }
        check()
        val after = access.stat(id)
        if (before != after || (after.size != null && after.size >= 0 && after.size != total.toLong())) {
            throw WatchedReadException("source_changed")
        }
        if (!validHeader(before.name, header.toByteArray())) throw WatchedReadException("unsupported_or_oversized")
        val sha = hash.digest().hex()
        // Providers may omit size/mtime or retain both after a same-size rewrite.
        val revision = digest("${before.fingerprint}:$sha".toByteArray(Charsets.UTF_8))
        return WatchedRead(sha, revision, before.fingerprint, total, output?.toByteArray())
    }
}
