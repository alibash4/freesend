package com.freesend.free_send

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Answers whether a VPN is up.
///
/// Local sharing needs the real local link: a VPN client routes traffic
/// through its tunnel and the hotspot or the shared Wi-Fi stops being visible
/// to the other device.
class NetworkProbeBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "free_send/network")

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isVpnActive" -> result.success(isVpnActive())
            "isLocationEnabled" -> result.success(isLocationEnabled())
            "isWifiEnabled" -> result.success(isWifiEnabled())
            "openSettings" -> openSettings(call.argument<String>("target"), result)
            else -> result.notImplemented()
        }
    }

    /// Android 10 and newer refuses LocalOnlyHotspot while location services are
    /// off, which otherwise surfaces as a confusing SecurityException.
    private fun isLocationEnabled(): Boolean {
        val manager = context.applicationContext
            .getSystemService(Context.LOCATION_SERVICE)
                as? LocationManager ?: return true
        return manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    /// Local sharing runs over Wi-Fi: the hotspot a phone creates and the
    /// network two devices already share both need the radio on.
    @Suppress("DEPRECATION")
    private fun isWifiEnabled(): Boolean {
        val wifi = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? WifiManager
                ?: return true
        return wifi.isWifiEnabled
    }

    /// Jumps to the system settings page that owns the switch a checklist row
    /// is waiting on. Falls back to the main Settings screen when a device
    /// does not expose the specific page.
    private fun openSettings(target: String?, result: MethodChannel.Result) {
        val specific = when (target) {
            "wifi" -> Intent(Settings.ACTION_WIFI_SETTINGS)
            "location" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            else -> Intent("android.settings.VPN_SETTINGS")
        }
        val flags = Intent.FLAG_ACTIVITY_NEW_TASK
        try {
            context.startActivity(specific.addFlags(flags))
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            try {
                context.startActivity(
                    Intent(Settings.ACTION_SETTINGS).addFlags(flags),
                )
                result.success(true)
            } catch (e2: ActivityNotFoundException) {
                result.success(false)
            }
        }
    }

    private fun isVpnActive(): Boolean {
        val manager = context.applicationContext
            .getSystemService(Context.CONNECTIVITY_SERVICE)
                as? ConnectivityManager ?: return false
        return manager.allNetworks.any { network ->
            manager.getNetworkCapabilities(network)
                ?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        }
    }
}
