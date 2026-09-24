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

    init {
        YukariVpnService.onTunFdReady = { fd ->
            activity.runOnUiThread {
                pendingStartResult?.success(mapOf("fd" to fd))
                pendingStartResult = null
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

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.startForegroundService(intent)
                } else {
                    activity.startService(intent)
                }

                pendingStartResult = result
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
}
