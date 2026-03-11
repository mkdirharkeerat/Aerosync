package com.aerosync.network

import android.os.BatteryManager
import android.os.Build
import com.aerosync.service.AeroSyncNotificationListener
import com.aerosync.service.AeroSyncService
import okhttp3.*
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class AeroSyncWebSocketClient(
    private val service: AeroSyncService,
    private val serverIp: String,
    private val serverPort: Int = 8920
) {

    private var webSocket: WebSocket? = null
    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .retryOnConnectionFailure(true)
        .build()

    fun connect() {
        val url = "ws://$serverIp:$serverPort"
        val request = Request.Builder().url(url).build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                service.onConnected()
                sendHandshake()
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleIncomingMessage(text)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                service.onDisconnected()
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                service.onDisconnected()
            }
        })
    }

    fun disconnect() {
        webSocket?.close(1000, "User disconnected")
        webSocket = null
    }

    fun sendPacket(type: String, payload: String) {
        val json = JSONObject().apply {
            put("type", type)
            put("payload", payload)
            put("timestamp", System.currentTimeMillis() / 1000.0)
        }
        webSocket?.send(json.toString())
    }

    private fun sendHandshake() {
        val batteryStatus = service.getBatteryInfo()
        val payload = JSONObject().apply {
            put("deviceName", "${Build.MANUFACTURER} ${Build.MODEL}")
            put("batteryLevel", batteryStatus.first)
            put("isCharging", batteryStatus.second)
            put("tailscaleIp", service.getTailscaleIp())
        }
        sendPacket("HANDSHAKE", payload.toString())
    }

    private fun handleIncomingMessage(text: String) {
        try {
            val json = JSONObject(text)
            val type = json.optString("type")
            val payload = json.optString("payload")

            when (type) {
                "CALL_DIAL" -> {
                    service.callController.makeCall(payload)
                }
                "CALL_ACTION" -> {
                    if (payload == "ANSWER") {
                        service.callController.answerCall()
                    } else if (payload == "REJECT") {
                        service.callController.endCall()
                    }
                }
                "NOTIFICATION_REPLY" -> {
                    val replyObj = JSONObject(payload)
                    val id = replyObj.getString("id")
                    val replyText = replyObj.getString("text")
                    AeroSyncNotificationListener.sendQuickReply(service, id, replyText)
                }
                "TERMINAL_RESPONSE" -> {
                    service.onTerminalResponse(payload)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
