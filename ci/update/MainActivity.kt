package io.github.batlh.gluckspfennig

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Ersetzt die von flutter create erzeugte MainActivity (ci/prepare.sh, Vorlage in ci/update).
// Kanal für Updates: Ablageordner, Installationserlaubnis und Start der Installation.
class MainActivity : FlutterActivity() {
    private var multicast: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Mehrspieler im WLAN: Ohne diese Sperre verwirft Android die Rundrufe, mit denen sich Tische melden
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gluckspfennig/net").setMethodCallHandler { call, result ->
            when (call.method) {
                "lockMulticast" -> {
                    if (multicast == null) {
                        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        multicast = wifi.createMulticastLock("gluckspfennig").apply { setReferenceCounted(false); acquire() }
                    }
                    result.success(null)
                }
                "unlockMulticast" -> {
                    multicast?.release()
                    multicast = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gluckspfennig/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "cacheDir" -> result.success(File(cacheDir, "updates").apply { mkdirs() }.absolutePath)
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()
                )
                "allowInstall" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                    }
                    result.success(null)
                }
                "install" -> {
                    val file = File(call.argument<String>("path")!!)
                    val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                    val intent = Intent(Intent.ACTION_VIEW)
                        .setDataAndType(uri, "application/vnd.android.package-archive")
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
