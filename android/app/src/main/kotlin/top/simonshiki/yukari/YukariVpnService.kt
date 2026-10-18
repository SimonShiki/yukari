package top.simonshiki.yukari

import android.app.Notification
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor

class YukariVpnService : VpnService() {
    companion object {
        @JvmStatic
        var instance: YukariVpnService? = null

        @JvmStatic
        var onTunFdReady: ((Int) -> Unit)? = null

        /** Reports why the TUN device could not be created, to the app. */
        @JvmStatic
        var onTunFailed: ((String) -> Unit)? = null

        const val EXTRA_NETWORK_NAME = "network_name"
        const val EXTRA_IPV4_ADDR = "ipv4_addr"
        const val EXTRA_MTU = "mtu"
        const val EXTRA_ROUTES = "routes"
        const val EXTRA_DNS = "dns"
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var networkName: String? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        networkName = intent?.getStringExtra(EXTRA_NETWORK_NAME) ?: "Yukari"
        val ipv4Addr = intent?.getStringExtra(EXTRA_IPV4_ADDR) ?: "10.144.144.1/24"
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

        try {
            vpnInterface = createVpnInterface(ipv4Addr, mtu, routes, dns)
            val fd = vpnInterface?.fd ?: throw IllegalStateException("Failed to get TUN fd")

            onTunFdReady?.invoke(fd)
            instance = this
        } catch (e: Exception) {
            onTunFailed?.invoke(e.message ?: "Could not establish the VPN")
            stopSelf()
            return START_NOT_STICKY
        }

        return START_STICKY
    }

    /** Redraws the foreground notification with the running network's state. */
    fun updateNotification(notification: Notification) {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.notify(YukariNotifications.VPN_NOTIFICATION_ID, notification)
    }

    private fun createVpnInterface(
        ipv4Addr: String,
        mtu: Int,
        routes: Array<String>,
        dns: String?
    ): ParcelFileDescriptor {
        val builder = Builder()
            .setSession("Yukari")
            .setBlocking(false)
            .setMtu(mtu)

        val ipParts = ipv4Addr.split("/")
        builder.addAddress(ipParts[0], ipParts.getOrElse(1) { "24" }.toInt())

        dns?.let { builder.addDnsServer(it) }

        routes.forEach { route ->
            val parts = route.split("/")
            if (parts.size == 2) {
                builder.addRoute(parts[0], parts[1].toInt())
            }
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
        instance = null
        super.onDestroy()
    }

    override fun onRevoke() {
        vpnInterface?.close()
        instance = null
        super.onRevoke()
    }
}
