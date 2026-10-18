package top.simonshiki.yukari

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * The running-network notification: the VPN service's foreground notification
 * while a TUN device exists, and a regular notification for a no-TUN network.
 *
 * Flutter sends the content, because it owns the peers and the traffic; this
 * file only draws it and wires the Stop action.
 */
object YukariNotifications {
    const val CHANNEL_ID = "yukari_vpn"

    /** The VPN service's foreground notification; it must not be 0. */
    const val VPN_NOTIFICATION_ID = 1

    /** The notification a running network without a VPN service shows. */
    private const val APP_NOTIFICATION_ID = 2
    private const val OPEN_REQUEST = 0
    private const val STOP_REQUEST = 1

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = context.getString(R.string.notification_channel_description)
                setShowBadge(false)
            },
        )
    }

    fun build(context: Context, title: String, text: String, stopLabel: String): Notification {
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
        val stop = Intent(context, MainActivity::class.java).apply {
            action = SystemUiChannel.STOP_ACTION
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentIntent(pending(context, OPEN_REQUEST, open))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(0, stopLabel, pending(context, STOP_REQUEST, stop))
            .build()
    }

    /** Shows the running network, wherever the notification can live. */
    fun update(context: Context, title: String, text: String, stopLabel: String) {
        createChannel(context)
        val service = YukariVpnService.instance
        if (service != null) {
            // A network that ran without a TUN device must not keep its
            // notification now that the VPN service owns the state.
            manager(context)?.cancel(APP_NOTIFICATION_ID)
            service.updateNotification(build(context, title, text, stopLabel))
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            // The user denied it; the network still runs, silently.
            return
        }
        manager(context)?.notify(APP_NOTIFICATION_ID, build(context, title, text, stopLabel))
    }

    /** Removes what [update] showed; the VPN service removes its own. */
    fun clear(context: Context) {
        manager(context)?.cancel(APP_NOTIFICATION_ID)
    }

    private fun pending(context: Context, requestCode: Int, intent: Intent): PendingIntent =
        PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    private fun manager(context: Context): NotificationManager? =
        context.getSystemService(NotificationManager::class.java)
}
