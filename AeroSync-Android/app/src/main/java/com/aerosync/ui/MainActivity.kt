package com.aerosync.ui

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.aerosync.service.AeroSyncService

class MainActivity : ComponentActivity() {

    private var isConnectedState by mutableStateOf(false)
    private var terminalOutputState by mutableStateOf("")

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                AeroSyncService.ACTION_STATUS_CHANGED -> {
                    isConnectedState = intent.getBooleanExtra("CONNECTED", false)
                }
                AeroSyncService.ACTION_TERMINAL_OUTPUT -> {
                    val out = intent.getStringExtra("OUTPUT") ?: ""
                    terminalOutputState += "\n➜ $out"
                }
            }
        }
    }

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { _ -> }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Request telephony and notification permissions
        val perms = mutableListOf(
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.CALL_PHONE
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            perms.add(Manifest.permission.ANSWER_PHONE_CALLS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            perms.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        permissionLauncher.launch(perms.toTypedArray())

        val filter = IntentFilter().apply {
            addAction(AeroSyncService.ACTION_STATUS_CHANGED)
            addAction(AeroSyncService.ACTION_TERMINAL_OUTPUT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }

        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    AeroSyncScreen(
                        isConnected = isConnectedState,
                        terminalLog = terminalOutputState,
                        onConnect = { ip ->
                            val intent = Intent(this, AeroSyncService::class.java).apply {
                                putExtra("SERVER_IP", ip)
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                        },
                        onDisconnect = {
                            AeroSyncService.instance?.disconnect()
                        },
                        onRunCommand = { cmd ->
                            terminalOutputState += "\n❯ $cmd"
                            AeroSyncService.instance?.sendPacket("TERMINAL_EXEC", cmd)
                        },
                        onOpenNotificationSettings = {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        }
                    )
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(receiver)
    }
}

@OptBehavior
@Composable
fun AeroSyncScreen(
    isConnected: Boolean,
    terminalLog: String,
    onConnect: (String) -> Unit,
    onDisconnect: () -> Unit,
    onRunCommand: (String) -> Unit,
    onOpenNotificationSettings: () -> Unit
) {
    var serverIp by remember { mutableStateOf("100.x.y.z") }
    var commandInput by remember { mutableStateOf("") }
    val scrollState = rememberScrollState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
            .verticalScroll(scrollState),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // App Title
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                text = "AeroSync",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold
            )
            AssistChip(
                onClick = {},
                label = { Text(if (isConnected) "Connected" else "Disconnected") },
                colors = AssistChipDefaults.assistChipColors(
                    labelColor = if (isConnected) Color(0xFF2E7D32) else Color(0xFFC62828)
                )
            )
        }

        // Connection Card
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(text = "Connect to Mac", fontWeight = FontWeight.SemiBold, fontSize = 18.sp)
                Text(
                    text = "Enter your Mac's Tailscale IP (100.x.y.z) or local Wi-Fi IP.",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                OutlinedTextField(
                    value = serverIp,
                    onValueChange = { serverIp = it },
                    label = { Text("Mac IP Address") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = { onConnect(serverIp) },
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("Connect")
                    }
                    if (isConnected) {
                        OutlinedButton(onClick = onDisconnect) {
                            Text("Disconnect")
                        }
                    }
                }
            }
        }

        // Remote Mac Terminal Controller Card
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(text = "Remote Mac Terminal", fontWeight = FontWeight.SemiBold, fontSize = 18.sp)
                Text(
                    text = "Execute shell commands or run Agy CLI on your Mac over Tailscale.",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                // Quick presets
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    SuggestionChip(
                        onClick = { onRunCommand("pmset displaysleepnow") },
                        label = { Text("Sleep Display", fontSize = 11.sp) }
                    )
                    SuggestionChip(
                        onClick = { onRunCommand("uptime") },
                        label = { Text("Uptime", fontSize = 11.sp) }
                    )
                    SuggestionChip(
                        onClick = { onRunCommand("~/.local/bin/agy --version") },
                        label = { Text("Agy CLI", fontSize = 11.sp) }
                    )
                }

                OutlinedTextField(
                    value = commandInput,
                    onValueChange = { commandInput = it },
                    label = { Text("Enter command (e.g. ls, agy...)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                Button(
                    onClick = {
                        if (commandInput.isNotBlank()) {
                            onRunCommand(commandInput)
                            commandInput = ""
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = isConnected
                ) {
                    Text("Execute on Mac")
                }

                // Output Console
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp)
                        .background(Color.Black, RoundedCornerShape(8.dp))
                        .padding(8.dp)
                ) {
                    Text(
                        text = terminalLog.ifEmpty { "Terminal output will appear here..." },
                        color = Color.Green,
                        fontSize = 11.sp,
                        fontFamily = FontFamily.Monospace
                    )
                }
            }
        }

        // Setup & Permissions Helper
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(text = "Permissions & Setup", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                Button(
                    onClick = onOpenNotificationSettings,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Grant Notification Listener Permission")
                }
            }
        }
    }
}
