package com.example.agenda

import android.content.pm.ApplicationInfo
import android.os.SystemClock
import android.util.Log
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry
import androidx.test.runner.lifecycle.Stage
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import io.flutter.embedding.android.FlutterFragment
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.TimeUnit
import java.util.concurrent.CompletableFuture
import java.io.File
import java.util.regex.Pattern

/** Drives only RevenueCat's native test dialogs in our isolated staging APK. */
@RunWith(AndroidJUnit4::class)
class StagingBillingReleaseTest {
    @Test(timeout = 480000)
    fun nativeCheckoutAndFlutterBackendEntitlements() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        assertEquals("com.example.agenda.staging", context.packageName)
        assertEquals(0, context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE)
        val device = UiDevice.getInstance(instrumentation)
        val flutterResults = CompletableFuture<Map<String, String>>()
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            // Flutter deliberately excludes dev plugins from release builds.
            // Receive its normal integration-test result protocol from the test
            // APK, without adding test dependencies to the distributable app.
            scenario.onActivity { activity ->
                val fragment = activity.supportFragmentManager.fragments
                    .filterIsInstance<FlutterFragment>().single()
                val messenger = requireNotNull(fragment.flutterEngine).dartExecutor.binaryMessenger
                MethodChannel(messenger, "plugins.flutter.io/integration_test")
                    .setMethodCallHandler { call, result ->
                        if (call.method == "allTestsFinished") {
                            flutterResults.complete(requireNotNull(call.argument<Map<String, String>>("results")))
                            result.success(null)
                        } else {
                            result.notImplemented()
                        }
                    }
            }
            // Check the actual native activity, independent of remote copy,
            // locale or whether its restore link falls below the viewport.
            val deadline = SystemClock.uptimeMillis() + 90000
            var paywallVisible = false
            while (!paywallVisible && SystemClock.uptimeMillis() < deadline) {
                instrumentation.runOnMainSync {
                    paywallVisible = ActivityLifecycleMonitorRegistry.getInstance()
                        .getActivitiesInStage(Stage.RESUMED).any {
                            it.javaClass.name == "com.revenuecat.purchases.ui.revenuecatui.activity.PaywallActivity" &&
                                it.window.decorView.hasWindowFocus()
                        }
                }
                if (flutterResults.isDone) break
                if (!paywallVisible) SystemClock.sleep(100)
            }
            assertTrue("The RevenueCat paywall did not open: ${flutterResults.getNow(emptyMap())}", paywallVisible)
            assertTrue("The paywall rendered no text", device.wait(
                Until.hasObject(By.pkg(context.packageName).text(Pattern.compile("(?s).+"))), 15000,
            ))
            device.waitForIdle()
            val evidence = File(context.getExternalFilesDir(null), "staging-release-paywall.png")
            assertTrue("Could not capture paywall evidence", device.takeScreenshot(evidence))
            device.dumpWindowHierarchy(File(context.getExternalFilesDir(null), "staging-release-paywall.xml"))
            Log.i("STAGING_RELEASE", "Paywall evidence: ${evidence.absolutePath}")
            device.pressBack()
            // The Dart test checks the distinct result from every button.
            for (button in listOf("button3", "button2", "button1")) {
                assertNotNull("Test Store checkout did not open", device.wait(
                    Until.findObject(By.text("Test Store Purchase")), 90000,
                ))
                val choice = device.wait(Until.findObject(By.res("android", button)), 10000)
                assertNotNull("Test Store choice missing: $button", choice)
                choice.click()
                assertTrue(device.wait(Until.gone(By.text("Test Store Purchase")), 10000))
            }
            val results = flutterResults.get(240, TimeUnit.SECONDS)
            assertFalse("No Flutter verification results", results.isEmpty())
            for ((name, result) in results) assertEquals(name, "success", result)
        }
    }
}
