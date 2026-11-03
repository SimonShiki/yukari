package top.simonshiki.yukari

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class VpnMethodChannel(private val activity: FlutterActivity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "top.simonshiki.yukari/vpn"
        const val VPN_PERMISSION_REQUEST = 1001
    }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingStartResult: MethodChannel.Result? = null

    /**
     * The failure that arrived before its start result existed. The service can
     * fail while the start call is still on the stack, and a start that is
     * never answered hangs in Dart.
     */
    private var startFailure: String? = null

    init {
        YukariVpnService.onTunFdReady = { fd ->
            activity.runOnUiThread {
                pendingStartResult?.success(mapOf("fd" to fd))
                pendingStartResult = null
            }
        }
        YukariVpnService.onTunFailed = { message ->
            activity.runOnUiThread {
                val pending = pendingStartResult
                pendingStartResult = null
                if (pending != null) {
                    pending.error("vpn_start_failed", message, null)
                } else {
                    startFailure = message
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestVpnPermission" -> {
                val intent = VpnService.prepare(activity)
                if (intent != null) {
                    activity.startActivityForResult(intent, VPN_PERMISSION_REQUEST)
                    pendingPermissionResult = result
                } else {
                    result.success(true)
                }
            }
            "hasVpnPermission" -> result.success(VpnService.prepare(activity) == null)
            "startVpn" -> {
                val intent = Intent(activity, YukariVpnService::class.java).apply {
                    putExtra(YukariVpnService.EXTRA_NETWORK_NAME, call.argument<String>("networkName"))
                    putExtra(YukariVpnService.EXTRA_IPV4_ADDR, call.argument<String>("ipv4"))
                    putExtra(YukariVpnService.EXTRA_MTU, call.argument<Int>("mtu"))
                    @Suppress("UNCHECKED_CAST")
                    val routesList = call.argument<List<String>>("routes")
                    putExtra(YukariVpnService.EXTRA_ROUTES, routesList?.toTypedArray())
                    putExtra(YukariVpnService.EXTRA_DNS, call.argument<String>("dns"))
                }

                startFailure = null
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        activity.startForegroundService(intent)
                    } else {
                        activity.startService(intent)
                    }
                } catch (error: Exception) {
                    // Android 12+ refuses a foreground service start from the
                    // background; the caller reports it instead of waiting.
                    result.error(
                        "vpn_start_failed",
                        error.message ?: "Could not start the VPN service",
                        null,
                    )
                    return
                }

                pendingStartResult = result
                // The service may have failed while the start call was on the
                // stack, before its result existed: answer that caller now.
                val failure = startFailure
                if (failure != null) {
                    startFailure = null
                    pendingStartResult = null
                    result.error("vpn_start_failed", failure, null)
                }
            }
            "stopVpn" -> {
                activity.stopService(Intent(activity, YukariVpnService::class.java))
                result.success(null)
            }
            "isVpnActive" -> {
                result.success(YukariVpnService.instance != null)
            }
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int) {
        if (requestCode == VPN_PERMISSION_REQUEST) {
            pendingPermissionResult?.success(resultCode == Activity.RESULT_OK)
            pendingPermissionResult = null
        }
    }

    fun detach() {
        YukariVpnService.onTunFdReady = null
        YukariVpnService.onTunFailed = null
        pendingPermissionResult = null
        pendingStartResult = null
        startFailure = null
    }
}
