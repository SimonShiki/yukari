package top.simonshiki.yukari

import android.app.Notification
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.OsConstants

class YukariVpnService : VpnService() {
    companion object {
        @JvmStatic
        var instance: YukariVpnService? = null

        @JvmStatic
        var onTunFdReady: ((Int) -> Unit)? = null

        /** Reports why the TUN device could not be created, to the app. */
        @JvmStatic
        var onTunFailed: ((String) -> Unit)? = null

        /** Reports when the system revokes VPN permission / replaces the VPN. */
        @JvmStatic
        var onVpnRevoked: (() -> Unit)? = null

        const val EXTRA_NETWORK_NAME = "network_name"
        const val EXTRA_ADDRESSES = "addresses"
        const val EXTRA_MTU = "mtu"
        const val EXTRA_ROUTES = "routes"
        const val EXTRA_DNS = "dns"
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var networkName: String? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val previousName = networkName
        networkName = intent?.getStringExtra(EXTRA_NETWORK_NAME) ?: "Yukari"
        val addresses = intent?.getStringArrayExtra(EXTRA_ADDRESSES)
            ?.filter { it.isNotBlank() }
            ?.toTypedArray()
            ?.takeIf { it.isNotEmpty() }
            ?: arrayOf("10.126.126.1/24")
        val mtu = intent?.getIntExtra(EXTRA_MTU, 1420) ?: 1420
        val routes = intent?.getStringArrayExtra(EXTRA_ROUTES) ?: arrayOf()
        val dns = intent?.getStringExtra(EXTRA_DNS)

        YukariNotifications.createChannel(this)
        startForeground(
            YukariNotifications.VPN_NOTIFICATION_ID,
            YukariNotifications.build(
                this,
                getString(R.string.tile_label),
                getString(R.string.notification_connected, networkName),
                getString(R.string.notification_stop),
            ),
        )

        val previousInterface = vpnInterface
        try {
            val nextInterface = createVpnInterface(addresses, mtu, routes, dns)
            vpnInterface = nextInterface
            previousInterface?.close()

            onTunFdReady?.invoke(nextInterface.fd)
            instance = this
        } catch (e: Exception) {
            networkName = previousName
            if (previousInterface != null) {
                updateNotification(
                    YukariNotifications.build(
                        this,
                        getString(R.string.tile_label),
                        getString(R.string.notification_connected, previousName ?: "Yukari"),
                        getString(R.string.notification_stop),
                    ),
                )
            }
            onTunFailed?.invoke(e.message ?: "Could not establish the VPN")
            if (previousInterface == null) {
                clearForegroundNotification()
                stopSelf()
                return START_NOT_STICKY
            }
        }

        return START_STICKY
    }

    /** Redraws the foreground notification with the running network's state. */
    fun updateNotification(notification: Notification) {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.notify(YukariNotifications.VPN_NOTIFICATION_ID, notification)
    }

    /** Takes back the notification of a start that could not establish. */
    private fun clearForegroundNotification() {
        stopForeground(Service.STOP_FOREGROUND_REMOVE)
        YukariNotifications.clearVpn(this)
    }

    private fun createVpnInterface(
        addresses: Array<String>,
        mtu: Int,
        routes: Array<String>,
        dns: String?
    ): ParcelFileDescriptor {
        val builder = Builder()
            .setSession("Yukari")
            .setBlocking(false)
            .setMtu(mtu)
            .allowFamily(OsConstants.AF_INET)
            .allowFamily(OsConstants.AF_INET6)

        addresses.forEach { addr ->
            val ipParts = addr.split("/")
            val defaultPrefix = if (ipParts[0].contains(':')) 64 else 24
            val prefix = ipParts.getOrNull(1)?.toIntOrNull() ?: defaultPrefix
            val maxPrefix = if (ipParts[0].contains(':')) 128 else 32
            require(ipParts.size <= 2 && prefix in 0..maxPrefix) { "Invalid VPN address: $addr" }
            builder.addAddress(ipParts[0], prefix)
        }

        dns?.let { builder.addDnsServer(it) }

        routes.forEach { route ->
            val parts = route.split("/")
            require(parts.size == 2) { "Invalid VPN route: $route" }
            val prefix = parts[1].toIntOrNull()
                ?: throw IllegalArgumentException("Invalid VPN route: $route")
            val maxPrefix = if (parts[0].contains(':')) 128 else 32
            require(prefix in 0..maxPrefix) { "Invalid VPN route: $route" }
            builder.addRoute(parts[0], prefix)
        }

        try {
            builder.addDisallowedApplication(packageName)
        } catch (e: Exception) {
            // Ignore if already added
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        return builder.establish()
            ?: throw IllegalStateException("Failed to establish VPN")
    }

    override fun onDestroy() {
        vpnInterface?.close()
        vpnInterface = null
        instance = null
        super.onDestroy()
    }

    override fun onRevoke() {
        vpnInterface?.close()
        vpnInterface = null
        instance = null
        clearForegroundNotification()
        onVpnRevoked?.invoke()
        stopSelf()
        super.onRevoke()
    }
}
