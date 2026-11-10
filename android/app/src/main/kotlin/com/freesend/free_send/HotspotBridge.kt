package com.freesend.free_send

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface
import java.net.SocketException

/**
 * Bridges the hotspot-only transport to Android:
 *  - host side: WifiManager.startLocalOnlyHotspot (no internet, WPA2)
 *  - client side: WifiNetworkSpecifier (API 29+) or legacy addNetwork
 *
 * Binding the process to the joined network is what lets the Dart socket code
 * route packets over the hotspot instead of mobile data.
 */
class HotspotBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL)
    private val handler = Handler(Looper.getMainLooper())

    private var reservation: WifiManager.LocalOnlyHotspotReservation? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var boundNetwork: Network? = null
    private var replied = false

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> startHotspot(result)
            "stop" -> {
                stopHotspot()
                result.success(null)
            }
            "join" -> joinHotspot(call, result)
            "leave" -> {
                leaveNetwork()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---------------------------------------------------------------- hosting

    private fun startHotspot(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error(
                "unsupported",
                "Android 8.0 or newer is required to create a hotspot on this device.",
                null,
            )
            return
        }
        val wifi = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? WifiManager
        if (wifi == null) {
            result.error("unsupported", "This device has no Wi-Fi adapter.", null)
            return
        }
        replied = false
        stopHotspot()
        try {
            wifi.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(res: WifiManager.LocalOnlyHotspotReservation) {
                    reservation = res
                    handler.post {
                        if (replied) {
                            res.close()
                            return@post
                        }
                        replied = true
                        result.success(
                            mapOf(
                                "ssid" to ssidOf(res),
                                "password" to passwordOf(res),
                                "ip" to hotspotAddress(),
                                "note" to null,
                            ),
                        )
                    }
                }

                override fun onStopped() {
                    handler.post {
                        if (replied) return@post
                        replied = true
                        result.error("stopped", "The hotspot was stopped by the system.", null)
                    }
                }

                override fun onFailed(reason: Int) {
                    handler.post {
                        if (replied) return@post
                        replied = true
                        result.error("failed", failureMessage(reason), null)
                    }
                }
            }, handler)
        } catch (error: SecurityException) {
            result.error(
                "permission",
                "Location (Nearby devices) permission is required to create a hotspot.",
                null,
            )
        } catch (error: Exception) {
            result.error("failed", error.message ?: "Could not start the hotspot.", null)
        }
    }

    private fun ssidOf(res: WifiManager.LocalOnlyHotspotReservation): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val ap = res.softApConfiguration
            if (!ap?.ssid.isNullOrEmpty()) return ap!!.ssid
        }
        @Suppress("DEPRECATION")
        val legacy = res.wifiConfiguration?.SSID ?: ""
        return legacy.trim('"')
    }

    private fun passwordOf(res: WifiManager.LocalOnlyHotspotReservation): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val ap = res.softApConfiguration
            if (!ap?.passphrase.isNullOrEmpty()) return ap!!.passphrase
        }
        @Suppress("DEPRECATION")
        val legacy = res.wifiConfiguration?.preSharedKey ?: ""
        return legacy.trim('"')
    }

    private fun stopHotspot() {
        reservation?.close()
        reservation = null
    }

    private fun failureMessage(reason: Int): String = when (reason) {
        WifiManager.LocalOnlyHotspotCallback.ERROR_NO_CHANNEL ->
            "No free Wi-Fi channel for a hotspot. Turn Wi-Fi off and on, then retry."
        WifiManager.LocalOnlyHotspotCallback.ERROR_INCOMPATIBLE_MODE ->
            "A hotspot cannot run while Wi-Fi is in this mode."
        WifiManager.LocalOnlyHotspotCallback.ERROR_TETHERING_DISALLOWED ->
            "The system does not allow a hotspot right now (check device policy)."
        else -> "The system could not start a hotspot."
    }

    // ---------------------------------------------------------------- joining

    private fun joinHotspot(call: MethodCall, result: MethodChannel.Result) {
        val ssid = call.argument<String>("ssid")
        val password = call.argument<String>("password")
        if (ssid.isNullOrEmpty()) {
            result.error("argument", "A hotspot name is required.", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            joinWithSpecifier(ssid, password, result)
        } else {
            joinLegacy(ssid, password, result)
        }
    }

    private fun joinWithSpecifier(
        ssid: String,
        password: String?,
        result: MethodChannel.Result,
    ) {
        val builder = WifiNetworkSpecifier.Builder().setSsid(ssid)
        if (!password.isNullOrEmpty()) {
            builder.setWpa2Passphrase(password)
        }
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(builder.build())
            .build()
        val manager = context.applicationContext
            .getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        if (manager == null) {
            result.error("unsupported", "Connectivity service unavailable.", null)
            return
        }
        leaveNetwork()
        replied = false
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                // Route every socket in this process over the hotspot link.
                manager.bindProcessToNetwork(network)
                boundNetwork = network
                handler.post {
                    if (replied) return@post
                    replied = true
                    result.success(
                        mapOf(
                            "ip" to localAddress(),
                            "note" to "Connected to \"$ssid\". Looking for the sharing device…",
                        ),
                    )
                }
            }

            override fun onUnavailable() {
                handler.post {
                    if (replied) return@post
                    replied = true
                    result.error(
                        "unavailable",
                        "The hotspot did not accept the connection. Check the name and password, and make sure it is still sharing.",
                        null,
                    )
                }
            }

            override fun onLost(network: Network) {
                if (boundNetwork == network) {
                    manager.bindProcessToNetwork(null)
                    boundNetwork = null
                }
            }
        }
        networkCallback = callback
        try {
            manager.requestNetwork(request, callback, 60000)
        } catch (error: SecurityException) {
            result.error("permission", "Wi-Fi permission is required to join a hotspot.", null)
        } catch (error: Exception) {
            result.error("failed", error.message ?: "Could not join the hotspot.", null)
        }
    }

    @Suppress("DEPRECATION")
    private fun joinLegacy(ssid: String, password: String?, result: MethodChannel.Result) {
        val wifi = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? WifiManager
        if (wifi == null) {
            result.error("unsupported", "This device has no Wi-Fi adapter.", null)
            return
        }
        try {
            val config = WifiConfiguration().apply {
                SSID = "\"$ssid\""
                if (!password.isNullOrEmpty()) {
                    preSharedKey = "\"$password\""
                    allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
                } else {
                    allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE)
                }
            }
            val netId = wifi.addNetwork(config)
            if (netId < 0) {
                result.error("failed", "The system rejected the hotspot details.", null)
                return
            }
            wifi.disconnect()
            val enabled = wifi.enableNetwork(netId, true)
            wifi.reconnect()
            if (!enabled) {
                result.error("failed", "Android would not enable that network.", null)
                return
            }
            handler.postDelayed({
                result.success(
                    mapOf(
                        "ip" to localAddress(),
                        "note" to "Connected to \"$ssid\". Looking for the sharing device…",
                    ),
                )
            }, 1500)
        } catch (error: SecurityException) {
            result.error("permission", "Location permission is required to join a hotspot.", null)
        } catch (error: Exception) {
            result.error("failed", error.message ?: "Could not join the hotspot.", null)
        }
    }

    private fun leaveNetwork() {
        val manager = context.applicationContext
            .getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        networkCallback?.let { callback ->
            try {
                manager?.unregisterNetworkCallback(callback)
            } catch (_: IllegalArgumentException) {
                // Never registered.
            }
        }
        networkCallback = null
        if (boundNetwork != null) {
            manager?.bindProcessToNetwork(null)
            boundNetwork = null
        }
    }

    // ------------------------------------------------------------------- utils

    /** Address of the access point itself, used to keep beacons on the link. */
    private fun hotspotAddress(): String? = addresses().firstOrNull { entry ->
        entry.first.contains("ap") ||
            entry.first.contains("wlan1") ||
            entry.first.contains("swlan") ||
            entry.second.startsWith("192.168.43.")
    }?.second ?: localAddress()

    /** First site-local IPv4 address of this device. */
    private fun localAddress(): String? = addresses().firstOrNull()?.second

    private fun addresses(): List<Pair<String, String>> {
        val found = mutableListOf<Pair<String, String>>()
        try {
            for (networkInterface in NetworkInterface.getNetworkInterfaces()) {
                if (!networkInterface.isUp || networkInterface.isLoopback) continue
                for (address in networkInterface.inetAddresses) {
                    if (address is Inet4Address && !address.isLoopbackAddress) {
                        found.add(networkInterface.name to address.hostAddress.orEmpty())
                    }
                }
            }
        } catch (_: SocketException) {
            // Fall through with whatever was collected.
        }
        return found
    }

    companion object {
        private const val CHANNEL = "com.freesend.free_send/hotspot"
    }
}
