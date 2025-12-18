package com.example.new_project_location

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import com.google.android.gms.location.Priority.PRIORITY_HIGH_ACCURACY
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.Locale

class LocationService : Service() {
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback

    private var xToken: String? = null
    private var xServer: String? = null
    private var xMedsoftToken: String? = null
    private var currentRoomId: String? = null
    private var currentLocationMode: String = "idle" // Default to idle, or based on start action
    private var smallestDisplacement = 10f // Initial displacement, 10 meters

    // Constants from patient app
    companion object {
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "location_service_channel"
        private const val LOCATION_INTERVAL = 10000L // 10 seconds
        private const val FASTEST_LOCATION_INTERVAL = 5000L // 5 seconds
        private const val FLUTTER_COMMUNICATION_ACTION = "com.example.new_project_location.FLUTTER_COMMUNICATION"
    }

    // New: OkHttpClient instance
    private val client = OkHttpClient()

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
        // Start foreground immediately on creation to prevent crash in newer Android versions
        startForeground(NOTIFICATION_ID, getNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        Log.d("LocationServiceTrack", "onStartCommand with action: $action")

        // 1. Process intent extras (credentials and room ID)
        intent?.let {
            xToken = it.getStringExtra("xToken") ?: xToken
            xServer = it.getStringExtra("xServer") ?: xServer
            xMedsoftToken = it.getStringExtra("xMedsoftToken") ?: xMedsoftToken
            currentRoomId = it.getStringExtra("roomId") ?: currentRoomId
        }

        // 2. Process action and start/restart location updates if needed
        when (action) {
            "start" -> {
                currentLocationMode = "activeRoom"
                restartLocationUpdates() // Restart updates with new mode/params
            }
            "startIdle" -> {
                currentLocationMode = "idle"
                restartLocationUpdates() // Restart updates with new mode/params
            }
            // Actions to update parameters without restarting location updates (already handled in step 1)
            "setXToken", "setXServer", "setXMedsoftToken", "setRoomId" -> {
                Log.d("LocationServiceTrack", "Updated params. Current mode: $currentLocationMode")
            }
            else -> stopSelf()
        }

        return START_STICKY
    }

    // New: Helper function to get the foreground notification
    private fun getNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE)

        val modeText = if (currentLocationMode == "activeRoom") "Идэвхтэй" else "Хүлээлгийн"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Medsoft Track")
            .setContentText("Байршил илгээгдэж байна... Төлөв: $modeText")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun startLocationUpdates() {
        try {
            // New: Use the dynamic smallestDisplacement parameter
            val locationRequest = LocationRequest.Builder(PRIORITY_HIGH_ACCURACY, LOCATION_INTERVAL)
                .setMinUpdateIntervalMillis(FASTEST_LOCATION_INTERVAL)
                .setMinUpdateDistanceMeters(smallestDisplacement) // Dynamic displacement applied
                .build()

            locationCallback = object : LocationCallback() {
                override fun onLocationResult(locationResult: LocationResult) {
                    locationResult.lastLocation?.let { location ->
                        Log.d("LocationServiceTrack", "Location: ${location.latitude}, ${location.longitude}. Disp: $smallestDisplacement")
                        sendLocationToAPI(location)
                    }
                }
            }

            fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, mainLooper)
        } catch (e: SecurityException) {
            Log.e("LocationServiceTrack", "Location permission not granted", e)
        }
    }

    private fun stopLocationUpdates(stopForeground: Boolean = true) {
        if (::locationCallback.isInitialized) {
            fusedLocationClient.removeLocationUpdates(locationCallback)
        }
        if (stopForeground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
    }

    // New: Restart function to apply the new displacement value
    private fun restartLocationUpdates() {
        Log.d(
            "LocationServiceTrack",
            "Restarting updates with new displacement: $smallestDisplacement meters. Mode: $currentLocationMode"
        )
        // Stop updates without stopping the service/notification if stopForeground is false
        stopLocationUpdates(false)
        startLocationUpdates()

        // Update notification content to reflect the current mode
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, getNotification())
    }

    // Updated: Uses OkHttpClient and incorporates dynamic location logic
    private fun sendLocationToAPI(location: Location) {
        if (xToken == null || xServer == null || xMedsoftToken == null) {
            Log.e("LocationServiceTrack", "API credentials not fully set. Stopping service.")
            stopSelf()
            return
        }

        val urlString: String
        val jsonBody: JSONObject = JSONObject().apply {
            put("lat", location.latitude)
            put("lng", location.longitude)
        }

        // --- Track App specific logic for dual endpoints and JSON body ---
        if (currentLocationMode == "activeRoom") {
            if (currentRoomId == null) {
                Log.e("LocationServiceTrack", "Room ID not set for activeRoom mode. Stopping service.")
                stopSelf()
                return
            }
            urlString = "https://app.medsoft.care/api/location/save/driver"
            jsonBody.put("roomId", currentRoomId)
        } else {
            urlString = "https://runner-api.medsoft.care/api/gateway/general/post/api/among/ambulance/save/location"
        }
        // --- End Track App specific logic ---

        val mediaType = "application/json; charset=utf-8".toMediaType()
        val requestBody = jsonBody.toString().toRequestBody(mediaType)

        // --- Track App specific headers ---
        val request = Request.Builder()
            .url(urlString)
            .post(requestBody)
            .addHeader("Content-Type", "application/json")
            .addHeader("X-Token", xToken!!)
            .addHeader("X-Tenant", xServer!!)
            .addHeader("X-Medsoft-Token", xMedsoftToken!!)
            .addHeader("Authorization", "Bearer $xMedsoftToken") // Note: Redundant X-Medsoft-Token is present here
            .build()
        // --- End Track App specific headers ---

        CoroutineScope(Dispatchers.IO).launch {
            try {
                client.newCall(request).execute().use { response ->
                    val responseBody = response.body?.string()

                    if (response.isSuccessful && responseBody != null) {
                        Log.d("LocationServiceTrack", "API Response Body: $responseBody")
                        try {
                            val json = JSONObject(responseBody)
                            val arrivedData = json.optJSONObject("data")

                            if (arrivedData != null) {
                                // Dynamic distance update logic from patient app
                                val distance = arrivedData.optDouble("distance", -1.0)
                                if (distance > 0) {
                                    val newDisplacement =
                                        String.format(Locale.US, "%.2f", distance).toFloat()

                                    if (newDisplacement != smallestDisplacement) {
                                        smallestDisplacement = newDisplacement
                                        // Restart to apply the new distance filter
                                        restartLocationUpdates()
                                    }
                                }
                            }

                        } catch (e: Exception) {
                            Log.e("LocationServiceTrack", "Failed to parse JSON for updates: $e")
                        }
                    } else {
                        Log.e(
                            "LocationServiceTrack",
                            "Failed to send location data. Status code: ${response.code}"
                        )
                        if (response.code == 401 || response.code == 403) {
                            sendBroadcastToFlutter("navigateToLogin")
                        }
                    }
                }
            } catch (e: IOException) {
                Log.e("LocationServiceTrack", "Error making POST request: $e")
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Location Service Channel",
                NotificationManager.IMPORTANCE_LOW // Use IMPORTANCE_LOW for background tracking
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    // New: Function to communicate back to Flutter (e.g., login failure)
    private fun sendBroadcastToFlutter(methodName: String) {
        val intent = Intent(FLUTTER_COMMUNICATION_ACTION)
        intent.putExtra("method", methodName)
        intent.putExtra("value_bool", true)

        sendBroadcast(intent)
    }

    override fun onDestroy() {
        stopLocationUpdates()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}