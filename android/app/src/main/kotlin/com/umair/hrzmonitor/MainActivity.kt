package com.umair.hrzmonitor

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.umair.hrzmonitor/notification"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startHRService()
                    result.success(true)
                }
                "stopService" -> {
                    stopHRService()
                    result.success(true)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: ""
                    val text = call.argument<String>("text") ?: ""
                    updateNotification(title, text)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startHRService() {
        val intent = Intent(this, HRMonitoringService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopHRService() {
        val intent = Intent(this, HRMonitoringService::class.java)
        intent.action = HRMonitoringService.ACTION_STOP_SERVICE
        startService(intent)
    }

    private fun updateNotification(title: String, text: String) {
        val intent = Intent(this, HRMonitoringService::class.java)
        intent.action = HRMonitoringService.ACTION_UPDATE_NOTIFICATION
        intent.putExtra(HRMonitoringService.EXTRA_TITLE, title)
        intent.putExtra(HRMonitoringService.EXTRA_TEXT, text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}

