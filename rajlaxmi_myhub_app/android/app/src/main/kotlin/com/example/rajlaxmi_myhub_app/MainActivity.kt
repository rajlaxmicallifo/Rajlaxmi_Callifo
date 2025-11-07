package com.example.rajlaxmi_myhub_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.CallLog
import android.database.Cursor
import android.Manifest
import android.content.pm.PackageManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "call_log_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            when (call.method) {
                "getCallLogs" -> {
                    if (hasPermission()) {
                        val callLogs = getSimpleCallLogs()
                        result.success(callLogs)
                    } else {
                        result.error("PERMISSION_DENIED", "Call log permission not granted", null)
                    }
                }
                "hasPermissions" -> {
                    result.success(hasPermission())
                }
                "getSimInfo" -> {
                    result.success(mapOf("availableSims" to 2)) // Assume 2 SIMs for testing
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasPermission(): Boolean {
        return checkSelfPermission(Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_GRANTED
    }

    private fun getSimpleCallLogs(): List<Map<String, Any>> {
        val callLogs = mutableListOf<Map<String, Any>>()
        var cursor: Cursor? = null

        try {
            val projection = arrayOf(
                CallLog.Calls.NUMBER,
                CallLog.Calls.CACHED_NAME,
                CallLog.Calls.TYPE,
                CallLog.Calls.DATE,
                CallLog.Calls.DURATION
            )

            val sortOrder = "${CallLog.Calls.DATE} DESC"
            val limit = "50" // Limit to 50 recent calls

            cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                projection,
                null,
                null,
                sortOrder
            )

            var callCount = 0
            cursor?.let {
                val numberIndex = it.getColumnIndex(CallLog.Calls.NUMBER)
                val nameIndex = it.getColumnIndex(CallLog.Calls.CACHED_NAME)
                val typeIndex = it.getColumnIndex(CallLog.Calls.TYPE)
                val dateIndex = it.getColumnIndex(CallLog.Calls.DATE)
                val durationIndex = it.getColumnIndex(CallLog.Calls.DURATION)

                while (it.moveToNext() && callCount < 50) {
                    val number = it.getString(numberIndex) ?: "Unknown"
                    val name = it.getString(nameIndex) ?: ""
                    val type = it.getInt(typeIndex)
                    val date = it.getLong(dateIndex)
                    val duration = it.getLong(durationIndex)

                    // Distribute calls between SIM1 and SIM2 for testing
                    val sim = if (callCount % 2 == 0) "sim1" else "sim2"

                    val callType = when (type) {
                        CallLog.Calls.INCOMING_TYPE -> "incoming"
                        CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                        CallLog.Calls.MISSED_TYPE -> "missed"
                        CallLog.Calls.REJECTED_TYPE -> "rejected"
                        CallLog.Calls.BLOCKED_TYPE -> "blocked"
                        CallLog.Calls.VOICEMAIL_TYPE -> "voicemail"
                        else -> "unknown"
                    }

                    callLogs.add(mapOf(
                        "number" to number,
                        "name" to name,
                        "type" to callType,
                        "date" to date,
                        "duration" to duration,
                        "sim" to sim
                    ))

                    callCount++
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            cursor?.close()
        }

        return callLogs
    }
}   