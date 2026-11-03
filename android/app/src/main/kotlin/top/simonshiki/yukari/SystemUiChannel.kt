package top.simonshiki.yukari

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Carries the tile and notification state from Flutter to the system UI, and
 * their taps back to Flutter.
 *
 * The channel only exists while the Flutter engine does. The tile and the
 * notification's Stop action first try [dispatch]; when no engine can take the
 * action they start [MainActivity] with it pending, so the control paths stay
 * in Dart either way. Dart may also ask for [MainActivity] when a background
 * start needs the foreground, with the same detached control path.
 */
class SystemUiChannel(
    private val activity: Activity,
    private val channel: MethodChannel,
    initialIntent: Intent?,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "top.simonshiki.yukari/system"

        /** The notification's Stop action, which the activity receives. */
        const val STOP_ACTION = "top.simonshiki.yukari.action.STOP"

        /** The action a launch from the tile or the notification carries. */
        const val EXTRA_ACTION = "top.simonshiki.yukari.extra.ACTION"

        /**
         * When that action was asked for. Android re-delivers a launch intent
         * when it recreates the activity, and a stale toggle must not run.
         */
        const val EXTRA_ACTION_AT = "top.simonshiki.yukari.extra.ACTION_AT"

        /** The tap came from the tile, so the app may be in the background. */
        const val SOURCE_TILE = "tile"

        /** The app was brought forward to run the action, so it may ask. */
        const val SOURCE_INTENT = "intent"

        private const val NOTIFICATION_PERMISSION_REQUEST = 1002

        @Volatile
        private var current: SystemUiChannel? = null

        @Volatile
        private var dartReady = false

        /** Runs [action] in Flutter, or answers false when no engine can. */
        fun dispatch(action: String, source: String): Boolean {
            val channel = current?.channel ?: return false
            if (!dartReady) return false
            return try {
                channel.invokeMethod(
                    "onAction",
                    mapOf("action" to action, "source" to source),
                )
                true
            } catch (error: Exception) {
                false
            }
        }

        /** The intent that brings the app up with [action] pending. */
        fun launchIntent(context: Context, action: String): Intent =
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_ACTION, action)
                putExtra(EXTRA_ACTION_AT, System.currentTimeMillis())
            }
    }

    private var pendingAction: Map<String, Any?>? = pendingOf(initialIntent)
    private var permissionResult: MethodChannel.Result? = null

    init {
        current = this
        dartReady = false
    }

    /** Runs the action an intent brought the activity to the front with. */
    fun handleIntent(intent: Intent?) {
        val action = actionOf(intent) ?: return
        if (!dispatch(action, SOURCE_INTENT)) pendingAction = pendingOf(intent)
    }

    fun detach() {
        if (current === this) {
            current = null
            dartReady = false
        }
        permissionResult = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ready" -> {
                dartReady = true
                result.success(null)
            }
            "takePendingAction" -> {
                val pending = pendingAction
                pendingAction = null
                result.success(pending)
            }
            "setTileState" -> {
                val active = call.argument<Boolean>("active") ?: false
                val label = call.argument<String>("label").orEmpty()
                if (TileStateStore.write(activity, active, label)) {
                    TileStateStore.requestUpdate(activity)
                }
                result.success(null)
            }
            "updateNotification" -> {
                if (call.argument<Boolean>("active") == true) {
                    YukariNotifications.update(
                        activity,
                        call.argument<String>("title")
                            ?: activity.getString(R.string.tile_label),
                        call.argument<String>("text").orEmpty(),
                        call.argument<String>("stopLabel")
                            ?: activity.getString(R.string.notification_stop),
                    )
                } else {
                    YukariNotifications.clear(activity)
                }
                result.success(null)
            }
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "openApp" -> {
                openApp(call.argument<String>("action") ?: "toggle")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return
        permissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        permissionResult = null
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.success(false)
            return
        }
        permissionResult = result
        activity.requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    private fun actionOf(intent: Intent?): String? = when {
        intent == null -> null
        intent.action == STOP_ACTION -> "stop"
        else -> intent.getStringExtra(EXTRA_ACTION)
    }

    /** The pending action Flutter runs, and when the system was asked for it. */
    private fun pendingOf(intent: Intent?): Map<String, Any?>? {
        val action = actionOf(intent) ?: return null
        intent?.removeExtra(EXTRA_ACTION)
        return mapOf(
            "action" to action,
            "source" to SOURCE_INTENT,
            "at" to (intent?.getLongExtra(EXTRA_ACTION_AT, 0L) ?: 0L),
        )
    }

    /**
     * Brings the app forward with [action] pending, as a background tile tap
     * that cannot finish on its own asks. The open panel's tile may launch an
     * activity from the background; the activity itself may be refused by
     * Android, and then nothing happens.
     */
    private fun openApp(action: String) {
        val tile = YukariTileService.listening
        val launched = if (tile == null) {
            false
        } else {
            try {
                tile.launchApp(action)
                true
            } catch (error: Exception) {
                // The panel may have closed since the tap; try the activity.
                false
            }
        }
        if (launched) return
        try {
            activity.startActivity(launchIntent(activity, action))
        } catch (error: Exception) {
            // Android may decline an activity start from the background.
        }
    }
}
