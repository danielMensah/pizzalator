package com.pizzalator.pizzalator

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /** lib/services/live_timer.dart. */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pizzalator/live_timer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        val ask = Manifest.permission.POST_NOTIFICATIONS
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(ask) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(ask), 0)
                        }
                        result.success(null)
                    }
                    "show" -> {
                        LiveTimer.show(
                            applicationContext,
                            call.argument<String>("legs")!!,
                            call.argument<Number>("startedAt")!!.toLong(),
                            call.argument<Number>("pausedAt")?.toLong(),
                        )
                        result.success(null)
                    }
                    "stop" -> result.success(LiveTimer.stop(applicationContext))
                    "chime" -> {
                        LiveTimer.chime(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
