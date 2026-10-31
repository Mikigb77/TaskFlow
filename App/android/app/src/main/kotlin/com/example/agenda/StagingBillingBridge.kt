package com.example.agenda

import android.content.Context
import android.content.pm.ApplicationInfo
import com.revenuecat.purchases.DangerousSettings
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.common.PlatformInfo
import com.revenuecat.purchases.hybridcommon.configure
import com.revenuecat.purchases.hybridcommon.mappers.mapAsync
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter 10.13.2 does not yet expose forceAllowTestStoreInReleaseBuilds.
 * Use the native SDK's documented opt-in for our private staging package only.
 * All checkout, receipts and entitlements still use the real RevenueCat SDK.
 */
class StagingBillingBridge(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "taskflow/staging-billing")
    private val purchasesChannel = MethodChannel(messenger, "purchases_flutter")
    private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "configure") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val key = call.argument<String>("apiKey")
            if (!BuildConfig.TASKFLOW_INTERNAL_STAGING ||
                context.packageName != "com.example.agenda.staging" ||
                !BuildConfig.TASKFLOW_TEST_STORE_KEY.startsWith("test_") ||
                key != BuildConfig.TASKFLOW_TEST_STORE_KEY
            ) {
                result.error("staging_billing_disabled", "Test Store requires the private staging build.", null)
                return@setMethodCallHandler
            }
            try {
                if (!Purchases.isConfigured) {
                    configure(
                        context = context.applicationContext,
                        apiKey = BuildConfig.TASKFLOW_TEST_STORE_KEY,
                        appUserID = call.argument<String>("appUserId"),
                        platformInfo = PlatformInfo("flutter", "10.13.2"),
                        dangerousSettings = DangerousSettings().apply {
                            forceAllowTestStoreInReleaseBuilds()
                        },
                        verificationMode = "INFORMATIONAL",
                        automaticDeviceIdentifierCollectionEnabled = false,
                    )
                }
                // Preserve the Flutter plugin's CustomerInfo stream when using
                // its native configure path, including after engine recreation.
                Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener { info ->
                    info.mapAsync { value ->
                        if (!closed) purchasesChannel.invokeMethod("Purchases-CustomerInfoUpdated", value)
                    }
                }
                result.success(mapOf(
                    "configured" to true,
                    "internalTestStore" to true,
                    "debuggable" to (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0),
                ))
            } catch (_: Exception) {
                result.error("staging_billing_configuration", "Could not configure staging purchases.", null)
            }
        }
    }

    fun close() {
        closed = true
        channel.setMethodCallHandler(null)
    }
}
