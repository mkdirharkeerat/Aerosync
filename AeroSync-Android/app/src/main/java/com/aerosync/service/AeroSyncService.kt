package com.aerosync.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.aerosync.network.AeroSyncWebSocketClient
import java.net.NetworkInterface

class AeroSyncService : Service() {

    companion object {
        var instance: AeroSyncService? = null
        const val CHANNEL_ID = "aerosync_foreground_channel"
        const val ACTION_STATUS_CHANGED = "com.aerosync.STATUS_CHANGED"
        const val ACTION_TERMINAL_OUTPUT = "com.aerosync.TERMINAL_OUTPUT"
    }

    lateinit var callController: CallController
    private var webSocketClient: AeroSyncWebSocketClient? = null
    var isConnected = false

    override fun onCreate() {
        super.onCreate()
        instance = this
        callController = CallController(this)
        callController.registerCallListener()
        createNotificationChannel()
        startForeground(1001, buildNotification("AeroSync Active", "Waiting to connect to Mac..."))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val serverIp = intent?.getStringExtra("SERVER_IP") ?: return START_STICKY
        connectToMac(serverIp)
        return START_STICKY
    }

    fun connectToMac(ip: String) {
        webSocketClient?.disconnect()
        webSocketClient = AeroSyncWebSocketClient(this, ip)
        webSocketClient?.connect()
    }

    fun disconnect() {
        webSocketClient?.disconnect()
        webSocketClient = null
        onDisconnected()
    }

    fun sendPacket(type: String, payload: String) {
        webSocketClient?.sendPacket(type, payload)
    }

    fun onConnected() {
        isConnected = true
        updateForegroundNotification("Connected to Mac", "Syncing notifications, calls & terminal")
        sendBroadcast(Intent(ACTION_STATUS_CHANGED).putExtra("CONNECTED", true))
    }

    fun onDisconnected() {
        isConnected = false
        updateForegroundNotification("Disconnected", "Waiting to reconnect...")
        sendBroadcast(Intent(ACTION_STATUS_CHANGED).putExtra("CONNECTED", false))
    }

    fun onTerminalResponse(output: String) {
        sendBroadcast(Intent(ACTION_TERMINAL_OUTPUT).putExtra("OUTPUT", output))
    }

    fun getBatteryInfo(): Pair<Int, Boolean> {
        val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: 100
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: 100
        val status = batteryIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        val batteryPct = if (level >= 0 && scale > 0) (level * 100) / scale else 100
        return Pair(batteryPct, isCharging)
    }

    fun getTailscaleIp(): String? {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val iface = interfaces.nextElement()
                if (iface.name.contains("tun") || iface.name.contains("tailscale")) {
                    val addrs = iface.inetAddresses
                    while (addrs.hasMoreElements()) {
                        val addr = addrs.nextElement()
                        val host = addr.hostAddress
                        if (host != null && host.startsWith("100.")) {
                            return host
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "AeroSync Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(true)
            .build()
    }

    private fun updateForegroundNotification(title: String, text: String) {
        val notification = buildNotification(title, text)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(1001, notification)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        webSocketClient?.disconnect()
        instance = null
    }
}
