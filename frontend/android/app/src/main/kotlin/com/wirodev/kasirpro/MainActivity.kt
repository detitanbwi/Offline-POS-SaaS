package com.wirodev.kasirpro

import android.media.MediaDrm
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.wirodev.kasirpro/device_id"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getWidevineId") {
                val id = getWidevineId()
                if (id != null) {
                    result.success(id)
                } else {
                    result.error("UNAVAILABLE", "Widevine ID not available.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getWidevineId(): String? {
        return try {
            val widevineUuid = UUID(-0x121074568629b532L, -0x5c37d8232ae2de13L)
            val mediaDrm = MediaDrm(widevineUuid)
            val widevineId = mediaDrm.getPropertyByteArray(MediaDrm.PROPERTY_DEVICE_UNIQUE_ID)
            
            val sb = java.lang.StringBuilder()
            for (b in widevineId) {
                sb.append(String.format("%02x", b))
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                mediaDrm.close()
            } else {
                @Suppress("DEPRECATION")
                mediaDrm.release()
            }
            sb.toString()
        } catch (e: Exception) {
            null
        }
    }
}
