import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:http/http.dart' as http;
import 'package:new_project_location/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  String _selectedRole = '';
  bool _isPasswordVisible = false;

  List<String> _serverNames = [];
  Map<String, String> sharedPreferencesData = {};

  static const platform = MethodChannel(
    'com.example.new_project_location/location',
  );

  Future<void> _getInitialScreenString() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String? xServer = prefs.getString('X-Server');
    bool isGotToken = xServer != null && xServer.isNotEmpty;

    String? xMedsoftServer = prefs.getString('X-Medsoft-Token');
    bool isGotMedsoftToken =
        xMedsoftServer != null && xMedsoftServer.isNotEmpty;

    String? username = prefs.getString('Username');
    bool isGotUsername = username != null && username.isNotEmpty;

    if (isLoggedIn && isGotToken && isGotMedsoftToken && isGotUsername) {
      debugPrint(
        'isLoggedIn: $isLoggedIn, isGotToken: $isGotToken, isGotMedsoftToken: $isGotMedsoftToken, isGotUsername: $isGotUsername',
      );
    } else {
      return debugPrint("empty shared");
    }
  }

  Future<void> _fetchServerData() async {
    const url = 'https://runner-api-v2.medsoft.care/api/gateway/servers';
    final headers = {'X-Token': Constants.xToken};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<String> serverNames = List<String>.from(
            data['data'].map((server) => server['name']),
          );

          setState(() {
            _serverNames = serverNames;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load servers.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error fetching server data.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Exception: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchServerData();
    _getInitialScreenString();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    if (_selectedRole.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a server';
        _isLoading = false;
      });
      return;
    }

    final body = {
      'username': _usernameController.text,
      'password': _passwordController.text,
    };

    final headers = {
      'X-Token': Constants.xToken,
      'X-Server': _selectedRole,
      'Content-Type': 'application/json',
    };

    debugPrint('Request Headers: $headers');
    debugPrint('Request Body: ${json.encode(body)}');

    try {
      final response = await http.post(
        Uri.parse('https://runner-api-v2.medsoft.care/api/gateway/auth'),
        headers: headers,
        body: json.encode(body),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        FlutterAppBadger.removeBadge();
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);

          final String token = data['data']['token'];

          await prefs.setString('X-Server', _selectedRole);
          await prefs.setString('X-Medsoft-Token', token);
          await prefs.setString('Username', _usernameController.text);

          // if (Platform.isIOS || Platform.isAndroid) {
          //   await FlutterAppBadger.updateBadgeCount(0);
          // }

          _loadSharedPreferencesData();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) {
                return const MyHomePage(title: 'Байршил тогтоогч');
              },
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Login failed: ${data['message']}';
            _isLoading = false;
          });
        }
      } else {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', false);
        setState(() {
          _errorMessage = 'Error logging in. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Exception: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSharedPreferencesData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, String> data = {};

    Set<String> allKeys = prefs.getKeys();
    for (String key in allKeys) {
      data[key] = prefs.getString(key) ?? 'null';
    }

    setState(() {
      sharedPreferencesData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 150.0, 16.0, 16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // const SizedBox(height: 20),
              Image.asset('assets/icon/locationlogologin.png', height: 150),

              Text(
                'Тавтай морил',
                style: TextStyle(
                  fontSize: 22.4,
                  color: Color(0xFF009688),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              if (_serverNames.isNotEmpty)
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFF808080),
                      width: 1.0,
                      style: BorderStyle.solid,
                      strokeAlign: -1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_hospital, color: Colors.black),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedRole.isEmpty ? null : _selectedRole,
                          hint: const Text('Эмнэлэг сонгох'),
                          isExpanded: true,
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedRole = newValue!;
                            });
                          },
                          items:
                              _serverNames.map<DropdownMenuItem<String>>((
                                String value,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                          underline: const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Нэвтрэх нэр',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible, // Use the toggle state
                decoration: InputDecoration(
                  labelText: 'Нууц үг',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible =
                            !_isPasswordVisible; // Toggle visibility
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // 'Нууц үг мартсан?' Label
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    // Handle the forgot password action here
                    // You can navigate to another screen or show a dialog
                  },
                  child: Text(
                    'Нууц үг мартсан?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF009688),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF009688),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: Size(double.infinity, 40),
                ),
                onPressed: _isLoading ? null : _login,
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'НЭВТРЭХ',
                          style: TextStyle(fontSize: 15, color: Colors.white),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
