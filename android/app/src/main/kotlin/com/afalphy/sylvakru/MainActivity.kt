package com.afalphy.sylvakru

import com.ryanheise.audioservice.AudioServiceActivity

import android.net.ConnectivityManager
import android.os.Build
import android.hardware.input.InputManager
import android.os.Handler
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.flame_engine.gamepads_android.GamepadsCompatibleActivity

class MainActivity: AudioServiceActivity(), GamepadsCompatibleActivity {
    var keyListener: ((KeyEvent) -> Boolean)? = null
    var motionListener: ((MotionEvent) -> Boolean)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Reports the system HTTP proxy (Wi-Fi/global proxy); Dart reads it via
        // the com.afalphy.system_proxy channel to route Dio and libmpv. VPN-mode
        // (TUN) proxies capture traffic transparently without a proxy config,
        // so this returns null then.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.afalphy.system_proxy").setMethodCallHandler { call, result ->
            when (call.method) {
                "getProxy" -> result.success(getSystemProxy())
                else -> result.notImplemented()
            }
        }
    }

    private fun getSystemProxy(): String? {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val info = (getSystemService(CONNECTIVITY_SERVICE) as? ConnectivityManager)?.defaultProxy
                if (info != null && !info.host.isNullOrEmpty() && info.port != 0) {
                    return "http://${info.host}:${info.port}"
                }
            }

            val host = System.getProperty("http.proxyHost")
            val port = System.getProperty("http.proxyPort")?.toIntOrNull()
            if (!host.isNullOrEmpty() && port != null && port != 0) {
                return "http://$host:$port"
            }
        } catch (_: Exception) {
        }
        return null
    }

    override fun dispatchGenericMotionEvent(motionEvent: MotionEvent): Boolean {
        return motionListener?.invoke(motionEvent) ?: false
    }

    override fun dispatchKeyEvent(keyEvent: KeyEvent): Boolean {
        if (keyListener?.invoke(keyEvent) == true) {
            return true
        }
        return super.dispatchKeyEvent(keyEvent)
    }

    override fun registerInputDeviceListener(
      listener: InputManager.InputDeviceListener, handler: Handler?) {
        val inputManager = getSystemService(INPUT_SERVICE) as InputManager
        inputManager.registerInputDeviceListener(listener, null)
    }

    override fun registerKeyEventHandler(handler: (KeyEvent) -> Boolean) {
        keyListener = handler
    }

    override fun registerMotionEventHandler(handler: (MotionEvent) -> Boolean) {
        motionListener = handler
    }
}
