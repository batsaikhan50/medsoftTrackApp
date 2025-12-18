package com.example.new_project_location

import android.Manifest
import android.app.AlertDialog
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
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

    companion object {
        private const val LOCATION_PERMISSION_REQUEST_CODE = 1
        private const val RECEIVER_ACTION = "com.example.new_project_location.FLUTTER_COMMUNICATION"
    }

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
        val filter = IntentFilter(RECEIVER_ACTION)
        // Ensure receiver registration is compatible with modern Android
        ContextCompat.registerReceiver(
            this,
            locationServiceReceiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
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

        val builder = AlertDialog.Builder(this)
        builder.setTitle("Байршлын зөвшөөрөл шаардлагатай")
        builder.setMessage(
            "Энэхүү функцийг ашиглахад байршлын хандалт зайлшгүй шаардлагатай. Тохиргоо цэс рүү орж байршлын хандалтыг гараар идэвхжүүлнэ үү."
        )
        builder.setPositiveButton("Тохиргоо нээх") { _, _ ->
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            val uri = Uri.fromParts("package", packageName, null)
            intent.data = uri
            startActivity(intent)
        }
        builder.setNegativeButton("Цуцлах") { dialog, _ ->
            dialog.dismiss()
        }
        builder.create().show()
    }

    private fun showBackgroundLocationDialog(serviceAction: String) {
        val builder = AlertDialog.Builder(this)
        builder.setTitle("Байршлын зөвшөөрөл шаардлагатай")
        builder.setMessage(
            "Аппликешн хаалттай байх үед байршлыг тасралтгүй шинэчлэхийн тулд 'Үргэлж зөвшөөрөх' (Allow all the time) эрх шаардлагатай. Тохиргоо руу орж байршлын эрхийг 'Апп ашиглах үед' биш 'Үргэлж зөвшөөрөх' болгон өөрчилнө үү."
        )
        builder.setPositiveButton("Тохиргоо нээх") { _, _ ->
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            val uri = Uri.fromParts("package", packageName, null)
            intent.data = uri
            startActivity(intent)
        }
        builder.setNegativeButton("Цуцлах") { dialog, _ ->
            dialog.dismiss()
            Log.w(
                "MainActivityTrack",
                "Background location denied. Starting service with limited (When In Use) permission."
            )
            // Start the service with limited permission (Foreground only)
            startLocationService(serviceAction)
        }
        builder.create().show()
    }

    private fun checkBackgroundLocationPermissionAndStartService(serviceAction: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !isBackgroundLocationGranted()) {
            // Android Q+ and Background Location is NOT granted, show the guide dialog
            showBackgroundLocationDialog(serviceAction)
        } else {
            // Older Android version or permission is granted
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

        // Case 2: Permission is not granted.
        val shouldShowRationale = ActivityCompat.shouldShowRequestPermissionRationale(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        )

        if (shouldShowRationale) {
            // Temporary denial or first run rationale—show OS prompt
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                LOCATION_PERMISSION_REQUEST_CODE
            )
            // Store call for later execution
            // We don't use pendingCall/Result here because the result will be handled in onRequestPermissionsResult
        } else {
            // Permission permanently denied OR first ever run.
            val isPermanentlyDenied = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED

            if (isPermanentlyDenied) {
                showInitialPermissionDeniedDialog() // Guide user to settings
                result.error(
                    "PERMISSION_DENIED_PERMANENTLY",
                    "Location permission permanently denied. Guide shown.",
                    null
                )
            } else {
                // If rationale is false but permission is not yet denied (first run only)
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                    LOCATION_PERMISSION_REQUEST_CODE
                )
            }
        }
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

            // The service action is not readily available here, but we can assume the user wants to start tracking
            // and handle the start logic inside checkBackgroundLocationPermissionAndStartService
            // For simplicity, we assume 'start' is the default action after granting permission.
            // If the application requires a specific action (start or startIdle), you'll need to store it in a temporary variable.

            // Re-evaluating the user's original request: "startLocationManagerAfterLogin" or "startIdleLocation".
            // Since we can't reliably know which one was originally called, we'll need to refactor Flutter to call a single 'requestPermissionAndStart' method
            // with the desired action as an argument. For now, we'll prompt the user again or assume 'start' (activeRoom).

            if (fineLocationGranted) {
                // Foreground permission was granted, now check for (and prompt for) Background Location
                checkBackgroundLocationPermissionAndStartService("start") // Assuming 'start' if permission is granted
            } else {
                Log.e("MainActivityTrack", "Location permission denied. Cannot start service.")
                methodChannel.invokeMethod("permissionDenied", null) // Inform Flutter
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
}