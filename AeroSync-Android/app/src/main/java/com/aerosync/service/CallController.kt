package com.aerosync.service

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.telecom.TelecomManager
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import org.json.JSONObject

class CallController(private val context: Context) {

    private val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
    private val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager

    fun registerCallListener() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyManager?.registerTelephonyCallback(
                context.mainExecutor,
                object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) {
                        handleState(state, null)
                    }
                }
            )
        } else {
            @Suppress("DEPRECATION")
            telephonyManager?.listen(object : PhoneStateListener() {
                @Deprecated("Deprecated in Java")
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    handleState(state, phoneNumber)
                }
            }, PhoneStateListener.LISTEN_CALL_STATE)
        }
    }

    private fun handleState(state: Int, incomingNumber: String?) {
        val statusString = when (state) {
            TelephonyManager.CALL_STATE_RINGING -> "RINGING"
            TelephonyManager.CALL_STATE_OFFHOOK -> "ACTIVE"
            else -> "IDLE"
        }

        val json = JSONObject().apply {
            put("status", statusString)
            put("number", incomingNumber ?: "Incoming Call")
            put("name", incomingNumber)
        }

        AeroSyncService.instance?.sendPacket("CALL_STATE", json.toString())
    }

    fun makeCall(phoneNumber: String) {
        try {
            val intent = Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:${Uri.encode(phoneNumber)}")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun answerCall() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                telecomManager?.acceptRingingCall()
            } catch (e: SecurityException) {
                e.printStackTrace()
            }
        }
    }

    fun endCall() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                telecomManager?.endCall()
            } catch (e: SecurityException) {
                e.printStackTrace()
            }
        }
    }
}
