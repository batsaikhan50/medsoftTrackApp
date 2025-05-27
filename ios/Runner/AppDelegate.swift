import BackgroundTasks
import CoreLocation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  var locationManager: CLLocationManager?
  var flutterChannel: FlutterMethodChannel?
  var xToken: String?
  var xServer: String?
  var xMedsoftToken: String?
  var didRequestAlwaysPermission = false
  var lastAuthorizationStatus: CLAuthorizationStatus?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    flutterChannel = FlutterMethodChannel(
      name: "com.example.new_project_location/location", binaryMessenger: controller.binaryMessenger
    )

    flutterChannel?.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "getLastLocation" {
        self?.getLastLocation(result: result)
      } else if call.method == "sendLocationToAPIByButton" {
        self?.sendLocationToAPIByButton(result: result)
      } else if call.method == "startLocationManagerAfterLogin" {
        self?.startLocationManagerAfterLogin()
        result(nil)
      } else if call.method == "sendXTokenToAppDelegate" {
        if let args = call.arguments as? [String: Any], let token = args["xToken"] as? String {
          self?.xToken = token
          print("Received xToken: \(self?.xToken ?? "No token")")
        }
        result(nil)
      } else if call.method == "sendXServerToAppDelegate" {
        if let args = call.arguments as? [String: Any],
          let hospital = args["xServer"] as? String
        {
          self?.xServer = hospital
          print("Received xServer: \(self?.xServer ?? "No token")")
        }
        result(nil)
      } else if call.method == "sendXMedsoftTokenToAppDelegate" {
        if let args = call.arguments as? [String: Any],
          let medsoftToken = args["xMedsoftToken"] as? String
        {
          self?.xMedsoftToken = medsoftToken
          print("Received xMedsoftToken: \(self?.xMedsoftToken ?? "No token")")
        }
        result(nil)
      } else if call.method == "stopLocationUpdates" {
        self?.stopLocationUpdates()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.example.new_project_location.sendLocation", using: nil
    ) { task in
      self.handleSendLocationTask(task: task)
    }

    scheduleBackgroundTask()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
      granted, error in
      if granted {
        NSLog("Notification permission granted.")
      } else {
        NSLog("Notification permission denied.")
      }
    }
  }

  private func getLastLocation(result: @escaping FlutterResult) {
    if let location = locationManager?.location {
      let locationData: [String: Double] = [
        "latitude": location.coordinate.latitude,
        "longitude": location.coordinate.longitude,
      ]
      result(locationData)
    } else {
      result(FlutterError(code: "LOCATION_ERROR", message: "Location not available", details: nil))
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    NSLog(
      "Background Location - Lat: \(location.coordinate.latitude), Lon: \(location.coordinate.longitude)"
    )

    let locationData: [String: Double] = [
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
    ]

    sendLocationToAPI(location: location)

    flutterChannel?.invokeMethod("updateLocation", arguments: locationData)

    if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
      didRequestAlwaysPermission = true
      requestAlwaysLocationPermission()
    }

    scheduleBackgroundTask()
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    NSLog("Failed to find user's location: \(error.localizedDescription)")
  }

  @objc func sendLocationToAPIByButton(result: @escaping FlutterResult) {

    guard let location = locationManager?.location else {
      result(FlutterError(code: "LOCATION_ERROR", message: "Location not available", details: nil))
      return
    }

    sendLocationToAPI(location: location)
    NSLog("button sent success")

    result(nil)
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus

    if status == .authorizedWhenInUse && lastAuthorizationStatus == .authorizedAlways {
      showLocationPermissionDialog()
    }

    lastAuthorizationStatus = status

    switch status {
    case .authorizedAlways:
      NSLog("Authorized Always")
      manager.startUpdatingLocation()
      requestNotificationPermission()
      didRequestAlwaysPermission = false  // Reset flag

    case .authorizedWhenInUse:
      Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
        // Your timed action here
        NSLog("Timer fired")
      }
      if didRequestAlwaysPermission && CLLocationManager.authorizationStatus() != .authorizedAlways
      {
        showLocationPermissionDialog()
        didRequestAlwaysPermission = false  // Reset flag
      }
      NSLog("Authorized When In Use")
      manager.startUpdatingLocation()

    case .denied, .restricted:
      NSLog("Location authorization denied or restricted.")
      showLocationPermissionDialog()
      manager.stopUpdatingLocation()

    case .notDetermined:
      NSLog("Not determined")
      locationManager?.requestWhenInUseAuthorization()
      break
    @unknown default:
      NSLog("Unknown location authorization status")
    }
  }

  func checkNotificationPermissionAndPromptIfNeeded() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        switch settings.authorizationStatus {
        case .notDetermined:
          self.requestNotificationPermission()

        case .denied:
          self.showNotificationPermissionDialog()

        case .authorized, .provisional, .ephemeral:
          NSLog("Notification permission granted or provisional.")

        @unknown default:
          NSLog("Unknown notification permission status.")
        }
      }
    }
  }

  func showNotificationPermissionDialog() {
    let alertController = UIAlertController(
      title: "Notification Permission Needed",
      message:
        "We need notification permission to send you important alerts. Would you like to enable it in Settings?",
      preferredStyle: .alert
    )

    let settingsAction = UIAlertAction(title: "Yes", style: .default) { _ in
      if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
      }
    }

    let cancelAction = UIAlertAction(title: "No", style: .cancel, handler: nil)

    alertController.addAction(settingsAction)
    alertController.addAction(cancelAction)

    if let topController = UIApplication.shared.keyWindow?.rootViewController {
      topController.present(alertController, animated: true, completion: nil)
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    checkLocationAuthorizationAndPromptIfNeeded()
    checkNotificationPermissionAndPromptIfNeeded()
  }

  func checkLocationAuthorizationAndPromptIfNeeded() {
    guard let manager = locationManager else { return }

    let status = manager.authorizationStatus

    if status == .authorizedWhenInUse {
      showLocationPermissionDialog()
    }
  }

  func showLocationPermissionDialog() {
    let alertController = UIAlertController(
      title: "Location Permission Needed",
      message:
        "To provide accurate location updates, we need access to your location always. Would you like to open settings and grant access?",
      preferredStyle: .alert
    )

    let containerView = UIStackView()
    containerView.axis = .vertical
    containerView.alignment = .center
    containerView.spacing = 10

    if let image = UIImage(named: "location_permission_image") {
      let imageView = UIImageView(image: image)
      imageView.contentMode = .scaleAspectFit
      containerView.addArrangedSubview(imageView)

      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.widthAnchor.constraint(equalToConstant: 261).isActive = true
      imageView.heightAnchor.constraint(equalToConstant: 261).isActive = true
    }

    alertController.view.addSubview(containerView)

    containerView.translatesAutoresizingMaskIntoConstraints = false
    containerView.topAnchor.constraint(equalTo: alertController.view.topAnchor, constant: 120)
      .isActive = true
    containerView.leadingAnchor.constraint(
      equalTo: alertController.view.leadingAnchor, constant: 20
    ).isActive = true
    containerView.trailingAnchor.constraint(
      equalTo: alertController.view.trailingAnchor, constant: -20
    ).isActive = true
    containerView.bottomAnchor.constraint(equalTo: alertController.view.bottomAnchor, constant: -50)
      .isActive = true

    let openSettingsAction = UIAlertAction(title: "Yes", style: .default) { _ in
      if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
        if UIApplication.shared.canOpenURL(settingsUrl) {
          UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
        }
      }
    }
    alertController.addAction(openSettingsAction)

    let clearAndLoginAction = UIAlertAction(title: "No", style: .destructive) { _ in
      self.clearSharedPreferencesAndNavigateToLogin()
    }
    alertController.addAction(clearAndLoginAction)

    if let topController = UIApplication.shared.keyWindow?.rootViewController {
      topController.present(alertController, animated: true, completion: nil)
    }
  }

  func requestAlwaysLocationPermission() {
    if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
      locationManager?.requestAlwaysAuthorization()
    }
    // if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
    //   showLocationPermissionDialog()
    // }
  }

  private func sendLocationToAPI(location: CLLocation) {
    guard let token = xToken else {
      NSLog("Error: xToken not available")
      return
    }

    guard let hospital = xServer else {
      NSLog("Error: xServer not available")
      return
    }

    guard let medsoftToken = xMedsoftToken else {
      NSLog("Error: xMedsoftToken not available")
      return
    }

    guard let url = URL(string: "https://runner-api-v2.medsoft.care/api/gateway/location") else {
      NSLog("Invalid URL")
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue(token, forHTTPHeaderField: "X-Token")

    request.addValue(hospital, forHTTPHeaderField: "X-Server")
    request.addValue(medsoftToken, forHTTPHeaderField: "X-Medsoft-Token")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
      "lat": location.coordinate.latitude,
      "lng": location.coordinate.longitude,
    ]

    do {
      let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
      request.httpBody = jsonData
    } catch {
      NSLog("Error encoding JSON body: \(error)")
      return
    }

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        NSLog("Error making POST request: \(error)")
        return
      }

      if let response = response as? HTTPURLResponse {
        NSLog("Response status code: \(response.statusCode)")

        if response.statusCode == 200 {
          NSLog("Successfully sent location data.")
        } else {
          NSLog("response.statusCode: \(response.statusCode)")

          if response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 400
          {
            DispatchQueue.main.async {
              self.clearSharedPreferencesAndNavigateToLogin()
            }
          } else {
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
              NSLog("Error response: \(responseString)")
            }
          }
        }
      }
    }
    task.resume()
  }

  func scheduleBackgroundTask() {
    let request = BGProcessingTaskRequest(
      identifier: "com.example.new_project_location.sendLocation")
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false

    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      NSLog("Failed to submit background task: \(error)")
    }
  }

  func handleSendLocationTask(task: BGTask) {

    if let location = locationManager?.location {
      sendLocationToAPI(location: location)
    }

    task.setTaskCompleted(success: true)
  }

  func startLocationManagerAfterLogin() {
    locationManager = CLLocationManager()
    locationManager?.delegate = self
    locationManager?.desiredAccuracy = kCLLocationAccuracyBest
    locationManager?.distanceFilter = 10
    locationManager?.allowsBackgroundLocationUpdates = true
    locationManager?.showsBackgroundLocationIndicator = false
    locationManager?.requestWhenInUseAuthorization()
  }

  func stopLocationUpdates() {

    locationManager?.stopUpdatingLocation()
    locationManager?.delegate = nil
    NSLog("Location updates stopped.")

    stopBackgroundTasks()
  }

  func stopBackgroundTasks() {
    BGTaskScheduler.shared.cancelAllTaskRequests()
    NSLog("Background tasks canceled.")
  }

  private func clearSharedPreferencesAndNavigateToLogin() {
    NSLog("clearSharedPreferencesAndNavigateToLogin")

    flutterChannel?.invokeMethod("navigateToLogin", arguments: nil)
  }

}
