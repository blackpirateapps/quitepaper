package com.blackpiratex.quietpaper.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class QuickCaptureWidgetTest {

    @Test
    fun testActionAndRequestCodeConstants() {
        assertEquals(
            "com.blackpiratex.quietpaper.QUICK_CAPTURE",
            QuickCaptureWidgetProvider.ACTION_QUICK_CAPTURE
        )
        assertEquals(1001, QuickCaptureWidgetProvider.REQUEST_CODE_CAPTURE)
    }

    @Test
    fun testProviderInstantiation() {
        val provider = QuickCaptureWidgetProvider()
        assertNotNull(provider)
    }
}
