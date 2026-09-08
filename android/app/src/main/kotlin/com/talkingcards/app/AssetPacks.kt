package com.talkingcards.app

import android.app.Activity
import com.google.android.play.core.assetpacks.AssetPackManager
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import com.google.android.play.core.assetpacks.AssetPackState
import com.google.android.play.core.assetpacks.AssetPackStateUpdateListener
import com.google.android.play.core.assetpacks.model.AssetPackStatus
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge between Play Asset Delivery and Dart's AssetPackService.
 *
 * Methods (all take {"pack": name}):
 *  - location → assetsPath() of the pack, or null while it is not on disk
 *  - fetch    → ask Play to (re)start the download
 *  - status   → one state map, or null when Play cannot say
 *  - confirm  → Play's own cellular-data dialog, when the pack waits for Wi-Fi
 *
 * Every AssetPackState update is pushed to Dart as "state" with the same map:
 * {status, bytesDownloaded, totalBytes, path?}.
 */
class AssetPacks(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, AssetPackStateUpdateListener {

    private val manager: AssetPackManager = AssetPackManagerFactory.getInstance(activity)
    private val channel = MethodChannel(messenger, "com.talkingcards.app/asset_packs")

    init {
        channel.setMethodCallHandler(this)
        manager.registerListener(this)
    }

    fun dispose() {
        manager.unregisterListener(this)
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val pack = call.argument<String>("pack")
        if (pack == null) {
            result.error("no_pack", "pack name required", null)
            return
        }
        when (call.method) {
            "location" -> result.success(manager.getPackLocation(pack)?.assetsPath())
            "fetch" -> {
                manager.fetch(listOf(pack))
                    .addOnSuccessListener { result.success(null) }
                    .addOnFailureListener { e -> result.error("fetch_failed", e.message, null) }
            }
            "status" -> {
                manager.getPackStates(listOf(pack))
                    .addOnSuccessListener { states ->
                        result.success(states.packStates()[pack]?.let { toMap(it) })
                    }
                    .addOnFailureListener { result.success(null) }
            }
            "confirm" -> {
                manager.showConfirmationDialog(activity)
                    .addOnCompleteListener { result.success(null) }
            }
            else -> result.notImplemented()
        }
    }

    override fun onStateUpdate(state: AssetPackState) {
        channel.invokeMethod("state", toMap(state))
    }

    private fun toMap(state: AssetPackState): Map<String, Any?> {
        val status = when (state.status()) {
            AssetPackStatus.PENDING -> "pending"
            AssetPackStatus.DOWNLOADING -> "downloading"
            AssetPackStatus.TRANSFERRING -> "transferring"
            AssetPackStatus.COMPLETED -> "completed"
            AssetPackStatus.FAILED -> "failed"
            AssetPackStatus.CANCELED -> "canceled"
            AssetPackStatus.WAITING_FOR_WIFI -> "waiting_for_wifi"
            AssetPackStatus.NOT_INSTALLED -> "not_installed"
            AssetPackStatus.REQUIRES_USER_CONFIRMATION -> "requires_user_confirmation"
            else -> "unknown"
        }
        val path = if (state.status() == AssetPackStatus.COMPLETED) {
            manager.getPackLocation(state.name())?.assetsPath()
        } else {
            null
        }
        return mapOf(
            "pack" to state.name(),
            "status" to status,
            "bytesDownloaded" to state.bytesDownloaded(),
            "totalBytes" to state.totalBytesToDownload(),
            "path" to path,
        )
    }
}
