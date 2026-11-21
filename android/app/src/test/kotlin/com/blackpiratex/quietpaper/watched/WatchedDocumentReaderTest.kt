package com.blackpiratex.quietpaper.watched

import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.InputStream

class WatchedDocumentReaderTest {
    private class Access(var bytes: ByteArray = "hello".toByteArray(), var name: String = "note.txt") : WatchedDocumentAccess {
        var size: Long? = bytes.size.toLong()
        var modified: Long? = 1
        var partial = false
        var virtual = false
        var closed = false
        var after: (() -> Unit)? = null
        var stream: InputStream? = null
        var opened = 0
        override fun stat(id: String) = WatchedDocument(id, name, "text/plain", size, modified, partial, virtual)
        override fun open(id: String): InputStream {
            opened++
            val source = stream ?: ByteArrayInputStream(bytes)
            return object : InputStream() {
                override fun read(): Int = source.read()
                override fun read(b: ByteArray, off: Int, len: Int): Int = source.read(b, off, len)
                override fun close() { closed = true; source.close(); after?.invoke() }
            }
        }
    }
    private fun read(access: Access, bytes: Boolean = true, limit: Int = 1000, cancelled: () -> Boolean = { false }) =
        WatchedDocumentReader.read(access, "opaque:id", limit, bytes, cancelled)
    private fun fails(code: String, action: () -> Unit) {
        try { action(); fail("Expected $code") } catch (e: WatchedReadException) { assertEquals(code, e.code) }
    }
    @Test fun readsExactBytesAndClosesWithoutMutatingSource() {
        val access = Access()
        val result = read(access)
        assertArrayEquals("hello".toByteArray(), result.bytes)
        assertArrayEquals("hello".toByteArray(), access.bytes)
        assertEquals("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824", result.hash)
        assertTrue(access.closed)
    }
    @Test fun hashOnlyReturnsNoSnapshot() { assertNull(read(Access(), bytes = false).bytes) }
    @Test fun unknownMetadataSameSizeRewriteChangesRevision() {
        val access = Access(); access.size = null; access.modified = null
        val first = read(access); access.bytes = "later".toByteArray()
        val second = read(access)
        assertEquals(first.fingerprint, second.fingerprint)
        assertNotEquals(first.revision, second.revision)
    }
    @Test fun lyingSizeAndTruncatedStreamsCannotCommit() {
        for (size in listOf(1L, 8L)) {
            val access = Access(); access.size = size
            fails("source_changed") { read(access) }; assertTrue(access.closed)
        }
    }
    @Test fun unknownOversizedStreamsReadOnlyOneBytePastBound() {
        val access = Access(); access.size = null
        var consumed = 0
        access.stream = object : InputStream() { override fun read(): Int { consumed++; return 65 } }
        fails("unsupported_or_oversized") { read(access, limit = 100) }
        assertEquals(101, consumed); assertTrue(access.closed)
    }
    @Test fun declaredOversizeRejectedBeforeOpening() {
        val access = Access(); access.size = 1001
        fails("unsupported_or_oversized") { read(access) }; assertEquals(0, access.opened)
    }
    @Test fun metadataMutationAfterReadRejected() {
        val access = Access(); access.after = { access.modified = 2 }
        fails("source_changed") { read(access) }; assertTrue(access.closed)
    }
    @Test fun cancellationDuringStreamClosesAndDiscardsBytes() {
        val access = Access(); var cancelled = false
        access.stream = object : ByteArrayInputStream("hello".toByteArray()) {
            override fun read(b: ByteArray, off: Int, len: Int): Int { cancelled = true; return super.read(b, off, len) }
        }
        fails("locked") { read(access, cancelled = { cancelled }) }; assertTrue(access.closed)
    }
    @Test fun cancellationBeforeReadNeverOpens() {
        val access = Access(); fails("locked") { read(access, cancelled = { true }) }; assertEquals(0, access.opened)
    }
    @Test fun nonProgressingStreamsAreBounded() {
        val access = Access(); access.stream = object : InputStream() {
            override fun read(): Int = 0
            override fun read(b: ByteArray, off: Int, len: Int): Int = 0
        }
        fails("source_unreadable") { read(access) }; assertTrue(access.closed)
    }
    @Test fun virtualPartialAndUnsafeNamesNeverOpen() {
        for (name in listOf("../escape.txt", "bad/name.txt", "bad\\name.txt", ".hidden.txt", "a\u0000b.txt", "file.part")) {
            val access = Access(name = name); fails("unsupported_or_oversized") { read(access) }; assertEquals(0, access.opened)
        }
        for (virtual in listOf(false, true)) {
            val access = Access(); access.virtual = virtual; access.partial = !virtual
            fails("unsupported_or_oversized") { read(access) }; assertEquals(0, access.opened)
        }
    }
    @Test fun binarySignaturesAndAliasesMatchPolicy() {
        val headers = mapOf("PDF" to "%PDF-1.7".toByteArray(), "png" to byteArrayOf(137.toByte(), 80, 78, 71, 13, 10, 26, 10),
            "JPG" to byteArrayOf(255.toByte(), 216.toByte(), 255.toByte()), "jpeg" to byteArrayOf(255.toByte(), 216.toByte(), 255.toByte()),
            "webp" to "RIFF0000WEBP".toByteArray())
        for ((ext, bytes) in headers) {
            assertArrayEquals(bytes, read(Access(bytes, "file.$ext")).bytes)
            fails("unsupported_or_oversized") { read(Access("not binary".toByteArray(), "file.$ext")) }
            fails("unsupported_or_oversized") { read(Access(byteArrayOf(), "file.$ext")) }
        }
        assertEquals(10 * 1024 * 1024, WatchedDocumentReader.limit("file.MARKDOWN"))
        assertEquals(50 * 1024 * 1024, WatchedDocumentReader.limit("file.EML"))
        assertNull(WatchedDocumentReader.limit("script.exe"))
    }
}
