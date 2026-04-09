package com.aerosync.service

import android.app.Notification
import android.app.RemoteInput
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap

class AeroSyncNotificationListener : NotificationListenerService() {

    companion object {
        private val activeActions = ConcurrentHashMap<String, Notification.Action>()

        fun sendQuickReply(context: android.content.Context, notificationId: String, replyText: String): Boolean {
            val action = activeActions[notificationId] ?: return false
            val remoteInputs = action.remoteInputs ?: return false
            val intent = Intent()
            val bundle = Bundle()
            for (input in remoteInputs) {
                bundle.putCharSequence(input.resultKey, replyText)
            }
            RemoteInput.addResultsToIntent(remoteInputs, intent, bundle)
            try {
                action.actionIntent.send(context, 0, intent)
                return true
            } catch (e: Exception) {
                e.printStackTrace()
                return false
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null || sbn.packageName == packageName) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        if (title.isEmpty() && text.isEmpty()) return

        val pm = packageManager
        val appName = try {
            val appInfo = pm.getApplicationInfo(sbn.packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            sbn.packageName
        }

        // Check if there is an inline reply action
        var hasReply = false
        notification.actions?.forEach { action ->
            if (action.remoteInputs != null && action.remoteInputs.isNotEmpty()) {
                hasReply = true
                activeActions[sbn.key] = action
            }
        }

        val json = JSONObject().apply {
            put("id", sbn.key)
            put("appName", appName)
            put("packageName", sbn.packageName)
            put("title", title)
            put("message", text)
            put("canReply", hasReply)
            put("timestamp", System.currentTimeMillis())
        }

        AeroSyncService.instance?.sendPacket("NOTIFICATION", json.toString())
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        sbn?.let { activeActions.remove(it.key) }
    }
}
