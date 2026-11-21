package com.blackpiratex.quietpaper.watched

import android.app.Activity
import android.content.Intent
import android.os.SystemClock
import android.net.Uri
import android.util.Base64
import android.view.accessibility.AccessibilityNodeInfo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.blackpiratex.quietpaper.MainActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Uses the real system tree picker, persistent grants and ExternalStorageProvider. */
@RunWith(AndroidJUnit4::class)
class WatchedFolderSafTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val auditName = "QuietPaperAudit-${UUID.randomUUID().toString().take(8)}"
    private lateinit var activity: MainActivity
    private lateinit var bridge: WatchedFolderBridge
    private class Reply : MethodChannel.Result {
        val done = CountDownLatch(1)
        var value: Any? = null
        var code: String? = null
        override fun success(result: Any?) { value = result; done.countDown() }
        override fun error(errorCode: String, message: String?, details: Any?) { code = errorCode; done.countDown() }
        override fun notImplemented() { code = "not_implemented"; done.countDown() }
        fun await(): Reply { assertTrue("Native method deadline", done.await(30, TimeUnit.SECONDS)); return this }
    }
    private fun invoke(method: String, args: Map<String, Any?> = emptyMap()): Reply {
        val result = Reply()
        instrumentation.runOnMainSync {
            WatchedFolderBridge::class.java.getDeclaredMethod("handle", MethodCall::class.java, MethodChannel.Result::class.java)
                .apply { isAccessible = true }.invoke(bridge, MethodCall(method, args), result)
        }
        return result
    }
    private fun call(method: String, args: Map<String, Any?> = emptyMap()): Any? {
        val reply = invoke(method, args).await()
        assertNull("Unexpected native error for $method: ${reply.code}", reply.code)
        return reply.value
    }
    private fun shell(command: String) {
        instrumentation.uiAutomation.executeShellCommand(command).use { fd ->
            java.io.FileInputStream(fd.fileDescriptor).use { it.readBytes() }
        }
    }
    private fun seed(relative: String, bytes: ByteArray) {
        shell("mkdir -p /sdcard/Download/$auditName/${relative.substringBeforeLast('/')} && echo '${Base64.encodeToString(bytes, Base64.NO_WRAP)}' | base64 -d > /sdcard/Download/$auditName/$relative")
    }
    private fun click(label: String, timeout: Long = 7000): Boolean {
        val until = SystemClock.elapsedRealtime() + timeout
        while (SystemClock.elapsedRealtime() < until) {
            val root = instrumentation.uiAutomation.rootInActiveWindow
            val queue = java.util.ArrayDeque<AccessibilityNodeInfo>()
            if (root != null) queue.add(root)
            while (queue.isNotEmpty()) {
                val node = queue.removeFirst()
                if (node.text?.toString()?.equals(label, true) == true || node.contentDescription?.toString()?.equals(label, true) == true) {
                    var target: AccessibilityNodeInfo? = node
                    repeat(6) {
                        if (target?.isClickable == true && target?.isEnabled == true) {
                            if (target!!.performAction(AccessibilityNodeInfo.ACTION_CLICK)) { SystemClock.sleep(400); return true }
                        }
                        target = target?.parent
                    }
                }
                for (i in 0 until node.childCount) node.getChild(i)?.let(queue::add)
            }
            SystemClock.sleep(100)
        }
        return false
    }
    private fun choose(folder: String): String {
        val result = invoke("chooseFolder")
        // The drawer label varies between AOSP DocumentsUI versions.
        val opened = click("Show roots", 2000) || click("Open navigation drawer", 2000)
        if (opened) assertTrue("Downloads root", click("Downloads"))
        assertTrue("Audit directory", click(auditName))
        assertTrue("Selected subfolder", click(folder))
        assertTrue("System folder grant", click("Use this folder"))
        click("Allow", 3000)
        result.await()
        assertNull(result.code)
        instrumentation.waitForIdleSync()
        return result.value as String
    }
    @Test fun realPickerMultipleGrantsVerifiedReadsRelatedImagesAndRevocation() {
        seed("one/source.txt", "source is immutable".toByteArray())
        seed("one/nested/note.md", "![Image](../images/pixel.png)".toByteArray())
        val png = instrumentation.context.assets.open("pixel.png").use { it.readBytes() }
        seed("one/images/pixel.png", png)
        seed("two/second.txt", "independent folder".toByteArray())
        activity = instrumentation.startActivitySync(Intent(Intent.ACTION_MAIN).apply {
            setClassName(instrumentation.targetContext.packageName, MainActivity::class.java.name)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }) as MainActivity
        bridge = MainActivity::class.java.getDeclaredMethod("getWatchedFolders").apply { isAccessible = true }.invoke(activity) as WatchedFolderBridge
        val grants = mutableListOf<String>()
        try {
            val one = choose("one"); grants.add(one)
            val two = choose("two"); grants.add(two)
            assertNotEquals(one, two)
            val resolver = activity.contentResolver
            assertTrue(resolver.persistedUriPermissions.any { it.uri.toString() == one && it.isReadPermission })
            @Suppress("UNCHECKED_CAST")
            val info = call("inspect", mapOf("root" to one)) as Map<String, Any?>
            assertEquals("one", info["name"])
            assertEquals(one, info["root"])
            val rootOne = call("start", mapOf("session" to "first", "root" to one, "identity" to info["identity"])) as String
            @Suppress("UNCHECKED_CAST")
            val infoTwo = call("inspect", mapOf("root" to two)) as Map<String, Any?>
            val rootTwo = call("start", mapOf("session" to "second", "root" to two, "identity" to infoTwo["identity"])) as String
            call("ready", mapOf("session" to "first", "ready" to true))
            call("ready", mapOf("session" to "second", "ready" to true))
            @Suppress("UNCHECKED_CAST")
            fun children(session: String, root: String): List<Map<String, Any?>> =
                (call("children", mapOf("session" to session, "parent" to root, "offset" to 0)) as Map<String, Any?>)["documents"] as List<Map<String, Any?>>
            val file = children("first", rootOne).single { it["name"] == "source.txt" }["id"] as String
            val second = children("second", rootTwo).single()["id"] as String
            @Suppress("UNCHECKED_CAST")
            fun read(session: String, id: String) = call("read", mapOf("session" to session, "id" to id, "limit" to 1024, "bytes" to true)) as Map<String, Any?>
            assertArrayEquals("source is immutable".toByteArray(), read("first", file)["bytes"] as ByteArray)
            assertEquals("unsafe_document", invoke("read", mapOf("session" to "first", "id" to second, "limit" to 1024, "bytes" to true)).await().code)
            assertArrayEquals(png, call("relatedImage", mapOf("session" to "first", "source" to listOf("nested", "note.md"), "target" to "../images/pixel.png")) as ByteArray)
            assertEquals("unsafe_image_path", invoke("relatedImage", mapOf("session" to "first", "source" to listOf("note.md"), "target" to "content://other/secret.png")).await().code)
            call("ready", mapOf("session" to "first", "ready" to false))
            assertEquals("locked", invoke("read", mapOf("session" to "first", "id" to file, "limit" to 1024, "bytes" to true)).await().code)
            assertArrayEquals("independent folder".toByteArray(), read("second", second)["bytes"] as ByteArray)
            call("stop", mapOf("session" to "first"))
            call("stop", mapOf("session" to "first"))
            assertArrayEquals("independent folder".toByteArray(), read("second", second)["bytes"] as ByteArray)
            instrumentation.runOnMainSync { bridge.setForeground(false) }
            assertEquals("locked", invoke("children", mapOf("session" to "second", "parent" to rootTwo, "offset" to 0)).await().code)
            instrumentation.runOnMainSync { bridge.setForeground(true) }
            resolver.releasePersistableUriPermission(Uri.parse(two), Intent.FLAG_GRANT_READ_URI_PERMISSION)
            assertEquals("permission_needed", invoke("inspect", mapOf("root" to two)).await().code)
            assertEquals("permission_needed", invoke("read", mapOf("session" to "second", "id" to second, "limit" to 1024, "bytes" to true)).await().code)
        } finally {
            for (root in grants) runCatching { activity.contentResolver.releasePersistableUriPermission(Uri.parse(root), Intent.FLAG_GRANT_READ_URI_PERMISSION) }
            instrumentation.runOnMainSync { activity.finish() }
            shell("rm -r /sdcard/Download/$auditName")
        }
    }
}
