package com.freesend.free_send

import android.content.Context
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
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
