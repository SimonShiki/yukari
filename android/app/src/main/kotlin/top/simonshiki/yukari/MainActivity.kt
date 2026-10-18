package top.simonshiki.yukari

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var vpnMethodChannel: VpnMethodChannel? = null
    private var systemUiChannel: SystemUiChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val vpnChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VpnMethodChannel.CHANNEL,
        )
        vpnMethodChannel = VpnMethodChannel(this)
        vpnChannel.setMethodCallHandler(vpnMethodChannel)

        val systemChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SystemUiChannel.CHANNEL,
        )
        systemUiChannel = SystemUiChannel(this, systemChannel, intent)
        systemChannel.setMethodCallHandler(systemUiChannel)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        systemUiChannel?.handleIntent(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        systemUiChannel?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        vpnMethodChannel?.onActivityResult(requestCode, resultCode)
    }

    override fun onDestroy() {
        systemUiChannel?.detach()
        vpnMethodChannel?.detach()
        systemUiChannel = null
        vpnMethodChannel = null
        super.onDestroy()
    }
}
