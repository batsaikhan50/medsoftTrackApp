import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:new_project_location/login.dart';
import 'package:new_project_location/webview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart'; // Adjust the path as needed

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  List<dynamic> patients = [];
  bool isLoading = true;
  String? username;
  Map<String, dynamic> sharedPreferencesData = {};

  @override
  void initState() {
    super.initState();
    fetchPatients();
    _loadSharedPreferencesData();
  }

  static const platform = MethodChannel(
    'com.example.new_project_location/location',
  );

  Future<void> fetchPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('X-Medsoft-Token') ?? '';
    final server = prefs.getString('X-Server') ?? '';

    final uri = Uri.parse('https://app.medsoft.care/api/room/get/driver');

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'X-Medsoft-Token': token,
        'X-Server': server,
        'X-Token': Constants.xToken,
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        setState(() {
          patients = json['data'];
          isLoading = false;
        });
      }
    } else {
      // Handle error
      setState(() => isLoading = false);
      debugPrint('Failed to fetch patients: ${response.statusCode}');
    }
  }

  void _logOut() async {
    debugPrint("Entered _logOut");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('X-Server');
    await prefs.remove('X-Medsoft-Token');
    await prefs.remove('Username');

    try {
      await platform.invokeMethod('stopLocationUpdates');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop location updates: '${e.message}'.");
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Future<void> _loadSharedPreferencesData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> data = {};

    Set<String> allKeys = prefs.getKeys();
    for (String key in allKeys) {
      if (key == 'isLoggedIn') {
        data[key] = prefs.getBool(key);
      } else {
        data[key] = prefs.getString(key) ?? 'null';
      }
    }

    setState(() {
      username = prefs.getString('Username');
      sharedPreferencesData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient List')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                padding: const EdgeInsets.all(12.0),
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final patient = patients[index];
                  final patientPhone = patient['patientPhone'] ?? 'Unknown';
                  final sentToPatient = patient['sentToPatient'] ?? false;
                  final patientSent = patient['patientSent'] ?? false;
                  final arrived = patient['arrived'] ?? false;
                  final distance = patient['distance'];
                  final duration = patient['duration'];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  patientPhone,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed:
                                    sentToPatient
                                        ? null
                                        : () {
                                          // TODO: Implement Send SMS
                                        },
                                child: const Text("Send SMS"),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed:
                                    patientSent
                                        ? () async {
                                          final url = patient['url'];
                                          final title = "Patient Map";
                                          final roomId = patient['roomId'];

                                          if (url != null &&
                                              url.toString().startsWith(
                                                'http',
                                              )) {
                                            try {
                                              // Send roomId to native side before starting location manager
                                              await platform.invokeMethod(
                                                'sendRoomIdToAppDelegate',
                                                {'roomId': roomId},
                                              );

                                              // Start location manager
                                              await platform.invokeMethod(
                                                'startLocationManagerAfterLogin',
                                              );

                                              // Then open the WebView
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          WebViewScreen(
                                                            url: url,
                                                            title: title,
                                                          ),
                                                ),
                                              );
                                            } on PlatformException catch (e) {
                                              debugPrint(
                                                "Failed to start location: $e",
                                              );
                                            }
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text("Invalid URL"),
                                              ),
                                            );
                                          }
                                        }
                                        : null,
                                child: const Text("See Map"),
                              ),
                            ],
                          ),
                          if (arrived) ...[
                            const SizedBox(height: 8),
                            Text("Distance: ${distance ?? 'N/A'} km"),
                            Text("Duration: ${duration ?? 'N/A'}"),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
