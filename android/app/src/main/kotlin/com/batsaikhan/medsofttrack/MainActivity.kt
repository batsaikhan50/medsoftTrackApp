package com.batsaikhan.medsofttrack

import android.Manifest
import android.app.AlertDialog
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.LayoutInflater
import android.view.WindowManager
import android.widget.Button
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    // Note: Retain the Track app's channel name
    private val CHANNEL = "com.example.medsoft_track/location"
    private lateinit var methodChannel: MethodChannel
    private var xToken: String? = null
    private var xServer: String? = null
    private var xMedsoftToken: String? = null
    private var currentRoomId: String? = null
    private var didRequestBackgroundLocationPermission = false
    private var lastLocationAuthorizationStatus: Int? = null
    private var pendingServiceAction: String? = null

    companion object {
        private const val LOCATION_PERMISSION_REQUEST_CODE = 1
        private const val BACKGROUND_LOCATION_PERMISSION_REQUEST_CODE = 3
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 2
        private const val RECEIVER_ACTION = "com.batsaikhan.medsofttrack.FLUTTER_COMMUNICATION"
    }

    private lateinit var sharedPreferences: SharedPreferences

    // New: Broadcast Receiver for Service-to-Flutter communication (e.g., navigateToLogin)
    private val locationServiceReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val method = intent?.getStringExtra("method")
            when (method) {
                "navigateToLogin" -> {
                    CoroutineScope(Dispatchers.Main).launch {
                        methodChannel.invokeMethod("navigateToLogin", null)
                    }
                }
                // Add any other Track-specific methods here if needed
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize SharedPreferences
        sharedPreferences = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val filter = IntentFilter(RECEIVER_ACTION)
        // Ensure receiver registration is compatible with modern Android
        ContextCompat.registerReceiver(
            this,
            locationServiceReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )

        // Get initial location authorization status
        lastLocationAuthorizationStatus = getLocationAuthorizationStatus()
    }

    override fun onResume() {
        super.onResume()
        // Similar to iOS's applicationDidBecomeActive
        checkLocationAuthorizationAndPromptIfNeeded()
        checkNotificationPermissionAndPromptIfNeeded()
    }

    override fun onDestroy() {
        unregisterReceiver(locationServiceReceiver)
        super.onDestroy()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // All methods that trigger location service or set parameters
                "startLocationManagerAfterLogin" -> handlePermissionAndStartService(call, result)
                "startIdleLocation" -> handlePermissionAndStartService(call, result)
                "sendXTokenToAppDelegate" -> setServiceParameter(
                    "setXToken",
                    "xToken",
                    call,
                    result
                )

                "sendXServerToAppDelegate" -> setServiceParameter(
                    "setXServer",
                    "xServer",
                    call,
                    result
                )

                "sendXMedsoftTokenToAppDelegate" -> setServiceParameter(
                    "setXMedsoftToken",
                    "xMedsoftToken",
                    call,
                    result
                )

                "sendRoomIdToAppDelegate" -> setServiceParameter(
                    "setRoomId",
                    "roomId",
                    call,
                    result
                )

                "stopLocationUpdates" -> {
                    val intent = Intent(this, LocationService::class.java)
                    stopService(intent)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    // Helper function to update service parameters
    private fun setServiceParameter(
        action: String,
        key: String,
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val value = call.argument<String>(key)
        val intent = Intent(this, LocationService::class.java)
        intent.action = action
        intent.putExtra(key, value)
        startService(intent)

        // Update local state for subsequent full service starts (e.g., after permission is granted)
        when (key) {
            "xToken" -> xToken = value
            "xServer" -> xServer = value
            "xMedsoftToken" -> xMedsoftToken = value
            "roomId" -> currentRoomId = value
        }
        result.success(null)
    }

    // ========== Location Permission Methods (Similar to iOS) ==========

    private fun getLocationAuthorizationStatus(): Int {
        return when {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                    ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.ACCESS_BACKGROUND_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                ) {
                    2 // Authorized Always
                } else {
                    1 // Authorized When In Use
                }
            }
            ActivityCompat.shouldShowRequestPermissionRationale(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) -> 0 // Not Determined
            else -> -1 // Denied or Restricted
        }
    }

    private fun checkLocationAuthorizationAndPromptIfNeeded() {
        val currentStatus = getLocationAuthorizationStatus()

        // Check if status changed from "Always" to "When In Use"
        if (lastLocationAuthorizationStatus == 2 && currentStatus == 1) {
            showLocationPermissionDialog()
            lastLocationAuthorizationStatus = currentStatus
            return
        }

        lastLocationAuthorizationStatus = currentStatus
    }


    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun getNotificationPermissionStatus(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            when (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            )) {
                PackageManager.PERMISSION_GRANTED -> 2 // Authorized
                else -> -1 // Denied or Not Determined
            }
        } else {
            // Pre-API 33: Check notification settings
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (notificationManager.areNotificationsEnabled()) {
                2 // Authorized
            } else {
                -1 // Denied
            }
        }
    }

    private fun checkNotificationPermissionAndPromptIfNeeded() {
        val isLoggedIn = sharedPreferences.getBoolean("flutter.isLoggedIn", false)

        if (!isLoggedIn) {
            Log.d("MainActivityTrack", "User not logged in, skipping notification permission check")
            return
        }

        when (getNotificationPermissionStatus()) {
            -1 -> showNotificationPermissionDialog() // Denied - show dialog
            0 -> {
                // Not Determined - request directly
                requestNotificationPermission()
            }
            else -> Log.d("MainActivityTrack", "Notification permission already granted")
        }
    }

    private fun showNotificationPermissionDialog() {
        // Show native permission dialog for notifications (Android 13+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE
            )
        } else {
            // For older Android versions, open notification settings
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            val uri = Uri.fromParts("package", packageName, null)
            intent.data = uri
            startActivity(intent)
        }
    }

    // --- Location Permission Logic from Patient App ---

    private fun checkLocationPermission(): Boolean {
        return (ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED)
    }

    private fun isBackgroundLocationGranted(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        }
        return true // For Android versions < Q, foreground permission is enough for background
    }

    private fun showInitialPermissionDeniedDialog() {
        // Open app settings directly - user can grant permission there
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        val uri = Uri.fromParts("package", packageName, null)
        intent.data = uri
        startActivity(intent)
    }

    private fun showBackgroundLocationDialog(serviceAction: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val view = LayoutInflater.from(this).inflate(R.layout.dialog_location_permission, null)
            val dialog = AlertDialog.Builder(this)
                .setView(view)
                .setCancelable(false)
                .create()
            dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

            view.findViewById<Button>(R.id.btn_open_settings).setOnClickListener {
                startActivity(Intent().apply {
                    action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                    data = Uri.fromParts("package", packageName, null)
                })
                startLocationService(serviceAction)
                dialog.dismiss()
            }
            view.findViewById<Button>(R.id.btn_continue).setOnClickListener {
                startLocationService(serviceAction)
                dialog.dismiss()
            }
            dialog.show()
            dialog.window?.setLayout(
                (resources.displayMetrics.widthPixels * 0.92).toInt(),
                WindowManager.LayoutParams.WRAP_CONTENT
            )
        } else {
            startLocationService(serviceAction)
        }
    }

    private fun showLocationPermissionDialog() {
        // Open app settings when user downgrades permission
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        val uri = Uri.fromParts("package", packageName, null)
        intent.data = uri
        startActivity(intent)
    }

    private fun checkBackgroundLocationPermissionAndStartService(serviceAction: String) {
        // If background location is already granted or not supported, just start service
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || isBackgroundLocationGranted()) {
            startLocationService(serviceAction)
        } else {
            // Background location not granted on Q+ - it will be requested in onResume()
            // For now, start service with foreground permission
            Log.d("MainActivityTrack", "Background location not granted, starting with foreground only")
            startLocationService(serviceAction)
        }
    }

    private fun handlePermissionAndStartService(call: MethodCall, result: MethodChannel.Result) {
        val serviceAction =
            if (call.method == "startLocationManagerAfterLogin") "start" else "startIdle"

        if (checkLocationPermission()) {
            // Case 1: Foreground permission already granted
            checkBackgroundLocationPermissionAndStartService(serviceAction)
            result.success(null)
            return
        }

        // Case 2: Permission is not granted - request foreground location first
        pendingServiceAction = serviceAction

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
            LOCATION_PERMISSION_REQUEST_CODE
        )
        result.success(null)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == LOCATION_PERMISSION_REQUEST_CODE) {
            val fineLocationGranted =
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED

            if (fineLocationGranted) {
                // Foreground location granted
                val action = pendingServiceAction ?: "start"

                // Check if we should ask for background location
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !isBackgroundLocationGranted()) {
                    // Show custom dialog to guide user to enable "always" location in settings
                    showBackgroundLocationDialog(action)
                } else {
                    // Already has background or pre-Q
                    startLocationService(action)
                }
                pendingServiceAction = null
            } else {
                Log.e("MainActivityTrack", "Location permission denied. Cannot start service.")
                methodChannel.invokeMethod("permissionDenied", null)
            }
        } else if (requestCode == BACKGROUND_LOCATION_PERMISSION_REQUEST_CODE) {
            // Background location permission response
            val backgroundGranted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (backgroundGranted) {
                Log.d("MainActivityTrack", "Background location permission granted")
            } else {
                Log.d("MainActivityTrack", "Background location permission denied or not granted")
            }
        } else if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d("MainActivityTrack", "Notification permission granted")
            } else {
                Log.d("MainActivityTrack", "Notification permission denied")
            }
        }
    }

    private fun startLocationService(action: String) {
        Log.d("MainActivityTrack", "Starting Location Service with action: $action")
        val intent = Intent(this, LocationService::class.java)

        // Pass all current necessary credentials for the service to function immediately
        intent.action = action
        intent.putExtra("xToken", xToken)
        intent.putExtra("xServer", xServer)
        intent.putExtra("xMedsoftToken", xMedsoftToken)
        intent.putExtra("roomId", currentRoomId)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(this, intent)
        } else {
            startService(intent)
        }
    }

    private fun clearSharedPreferencesAndNavigateToLogin() {
        Log.d("MainActivityTrack", "clearSharedPreferencesAndNavigateToLogin")
        methodChannel.invokeMethod("navigateToLogin", null)
    }
}
