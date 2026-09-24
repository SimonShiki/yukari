package top.simonshiki.yukari

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat

class YukariVpnService : VpnService() {
    companion object {
        @JvmStatic
        var instance: YukariVpnService? = null

        @JvmStatic
        var onTunFdReady: ((Int) -> Unit)? = null

        const val EXTRA_NETWORK_NAME = "network_name"
        const val EXTRA_IPV4_ADDR = "ipv4_addr"
        const val EXTRA_MTU = "mtu"
        const val EXTRA_ROUTES = "routes"
        const val EXTRA_DNS = "dns"

        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "yukari_vpn"
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var networkName: String? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        networkName = intent?.getStringExtra(EXTRA_NETWORK_NAME) ?: "Yukari"
        val ipv4Addr = intent?.getStringExtra(EXTRA_IPV4_ADDR) ?: "10.144.144.1/24"
        val mtu = intent?.getIntExtra(EXTRA_MTU, 1420) ?: 1420
        val routes = intent?.getStringArrayExtra(EXTRA_ROUTES) ?: arrayOf()
        val dns = intent?.getStringExtra(EXTRA_DNS)

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification(networkName!!))

        try {
            vpnInterface = createVpnInterface(ipv4Addr, mtu, routes, dns)
            val fd = vpnInterface?.fd ?: throw IllegalStateException("Failed to get TUN fd")

            onTunFdReady?.invoke(fd)
            instance = this
        } catch (e: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }

        return START_STICKY
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

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when Yukari VPN is active"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun createNotification(networkName: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Yukari VPN Active")
            .setContentText("Connected to $networkName")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
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
