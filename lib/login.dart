import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:http/http.dart' as http;
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:new_project_location/constants.dart';
import 'package:new_project_location/webview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final FocusNode _codeFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usernameController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, String>? _selectedRole;
  // String _selectedRole = '';
  bool _isPasswordVisible = false;
  int _selectedToggleIndex = 0; //0-Иргэн, 1-103
  double _dragPosition = 0.0;

  bool _isKeyboardVisible = false;

  List<Map<String, String>> _serverNames = [];
  Map<String, dynamic> sharedPreferencesData = {};

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    final newValue = bottomInset > 0.0;

    if (_isKeyboardVisible != newValue) {
      setState(() {
        _isKeyboardVisible = newValue;
      });
    }
  }

  // static const platform = MethodChannel(
  //   'com.example.new_project_location/location',
  // );

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
          final List<Map<String, String>> serverNames =
              List<Map<String, String>>.from(
                data['data'].map<Map<String, String>>((server) {
                  return {
                    'name': server['name'].toString(),
                    'url': server['url'].toString(),
                  };
                }),
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
    WidgetsBinding.instance.addObserver(this);
    _dragPosition =
        _selectedToggleIndex *
        // ignore: deprecated_member_use
        ((MediaQueryData.fromView(WidgetsBinding.instance.window).size.width -
                32 -
                8) /
            2);
    _fetchServerData();
    _getInitialScreenString();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    if (_selectedRole == null) {
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
      'X-Server': _selectedRole?['name'] ?? '',
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

          await prefs.setString('X-Server', _selectedRole?['name'] ?? '');
          await prefs.setString('X-Medsoft-Token', token);
          await prefs.setString('Username', _usernameController.text);

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
      sharedPreferencesData = data;
    });
  }

  Widget buildAnimatedToggle() {
    List<Map<String, String>> toggleOptions = [
      {'label': 'Иргэн', 'icon': 'assets/icon/userWithPhone.png'},
      {'label': '103', 'icon': 'assets/icon/ambulanceCar.png'},
    ];

    double totalWidth = MediaQuery.of(context).size.width - 32;
    double knobWidth = (totalWidth - 8) / 2;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragPosition += details.delta.dx;
          _dragPosition = _dragPosition.clamp(0, knobWidth);
        });
      },
      onHorizontalDragEnd: (_) {
        setState(() {
          if (_dragPosition < (knobWidth / 2)) {
            _selectedToggleIndex = 0;
            _dragPosition = 0;
          } else {
            _selectedToggleIndex = 1;
            _dragPosition = knobWidth;
          }
        });
      },
      onTapDown: (details) {
        final dx = details.localPosition.dx;
        setState(() {
          if (dx < totalWidth / 2) {
            _selectedToggleIndex = 0;
            _dragPosition = 0;
          } else {
            _selectedToggleIndex = 1;
            _dragPosition = knobWidth;
          }
        });
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: _dragPosition,
              top: 0,
              bottom: 0,
              width: knobWidth,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color:
                      _selectedToggleIndex == 0
                          ? const Color(0xFF1E88E5)
                          : const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),

            Row(
              children: List.generate(toggleOptions.length, (index) {
                final option = toggleOptions[index];
                final isSelected = index == _selectedToggleIndex;

                return Expanded(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          option['icon']!,
                          width: 24,
                          height: 24,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          option['label']!,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  KeyboardActionsConfig _buildKeyboardActionsConfig(BuildContext context) {
    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      nextFocus: true,
      keyboardBarColor: Colors.grey[200],
      actions: [
        if (_selectedToggleIndex == 0)
          KeyboardActionsItem(focusNode: _codeFocus),
        if (_selectedToggleIndex == 1) ...[
          KeyboardActionsItem(
            focusNode: _usernameFocus,
            displayArrows: true,
            onTapAction: () => _scrollIntoView(_usernameFocus),
          ),
          KeyboardActionsItem(
            focusNode: _passwordFocus,
            displayArrows: true,
            onTapAction: () => _scrollIntoView(_passwordFocus),
          ),
        ],
      ],
    );
  }

  void _scrollIntoView(FocusNode focusNode) {
    final context = focusNode.context;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child:
              _selectedToggleIndex == 1
                  ? KeyboardActions(
                    config: _buildKeyboardActionsConfig(context),
                    child: _buildLoginForm(),
                  )
                  : _buildLoginForm(),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 70,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Form(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/icon/locationlogologin.png', height: 150),
            const Text(
              'Тавтай морил',
              style: TextStyle(
                fontSize: 22.4,
                color: Color(0xFF009688),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            buildAnimatedToggle(),
            const SizedBox(height: 20),

            if (_selectedToggleIndex == 0)
              TextFormField(
                controller: _codeController,
                focusNode: _codeFocus,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Нэг удаагын код',
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            if (_selectedToggleIndex == 0) const SizedBox(height: 20),

            if (_serverNames.isNotEmpty && _selectedToggleIndex == 1)
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF808080),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_hospital, color: Colors.black),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<Map<String, String>>(
                        value: _selectedRole,
                        hint: const Text('Эмнэлэг сонгох'),
                        isExpanded: true,
                        onChanged: (Map<String, String>? newValue) async {
                          if (newValue != null) {
                            setState(() {
                              _selectedRole = newValue;
                              _errorMessage = '';
                            });
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setString(
                              'forgetUrl',
                              newValue['url'] ?? '',
                            );
                          }
                        },
                        items:
                            _serverNames
                                .map<DropdownMenuItem<Map<String, String>>>((
                                  Map<String, String> value,
                                ) {
                                  return DropdownMenuItem<Map<String, String>>(
                                    value: value,
                                    child: Text(value['name']!),
                                  );
                                })
                                .toList(),
                        underline: const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),

            if (_serverNames.isNotEmpty && _selectedToggleIndex == 1)
              const SizedBox(height: 20),

            if (_selectedToggleIndex == 1)
              TextFormField(
                controller: _usernameController,
                focusNode: _usernameFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_passwordFocus);
                },
                decoration: InputDecoration(
                  labelText: 'Нэвтрэх нэр',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            if (_selectedToggleIndex == 1) const SizedBox(height: 20),

            if (_selectedToggleIndex == 1)
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  _login();
                  FocusScope.of(context).unfocus();
                },
                obscureText: !_isPasswordVisible,
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
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            if (_selectedToggleIndex == 1) const SizedBox(height: 20),

            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            if (_selectedToggleIndex == 1)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () async {
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    String? baseUrl = prefs.getString('forgetUrl');
                    String? hospital = _selectedRole?['name'];

                    if (baseUrl != null &&
                        baseUrl.isNotEmpty &&
                        hospital != null) {
                      Navigator.push(
                        // ignore: use_build_context_synchronously
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => WebViewScreen(
                                url:
                                    '$baseUrl/forget?callback=medsofttrack://callback',
                                title: hospital,
                              ),
                        ),
                      );
                    } else {
                      setState(() {
                        _errorMessage =
                            'Нууц үг солихын тулд эмнэлэг сонгоно уу.';
                      });
                    }
                  },
                  child: const Text(
                    'Нууц үг мартсан?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF009688),
                    ),
                  ),
                ),
              ),

            if (_selectedToggleIndex == 1) const SizedBox(height: 10),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 40),
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
    );
  }
}
