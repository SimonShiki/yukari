package top.simonshiki.yukari

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var vpnMethodChannel: VpnMethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VpnMethodChannel.CHANNEL
        )
        vpnMethodChannel = VpnMethodChannel(this)
        channel.setMethodCallHandler(vpnMethodChannel)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        vpnMethodChannel?.onActivityResult(requestCode, resultCode)
    }

    override fun onDestroy() {
        vpnMethodChannel = null
        super.onDestroy()
    }
}
