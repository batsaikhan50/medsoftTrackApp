import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:medsoft_track/api/map_dao.dart';
import 'package:medsoft_track/login.dart';
import 'package:medsoft_track/webview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => PatientListScreenState();
}

class PatientListScreenState extends State<PatientListScreen> {
  List<dynamic> patients = [];
  bool isLoading = true;
  String? username;
  Map<String, dynamic> sharedPreferencesData = {};
  Timer? _refreshTimer;
  final Set<int> _expandedTiles = {};
  static const platform = MethodChannel('com.example.medsoft_track/location');
  final _mapDAO = MapDAO();

  @override
  void initState() {
    super.initState();
    fetchPatients(initialLoad: true);
    _loadSharedPreferencesData();

    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      refreshPatients();
    });
  }

  void refreshPatients() {
    fetchPatients();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchPatients({bool initialLoad = false}) async {
    if (initialLoad) {
      setState(() => isLoading = true);
    }

    // final prefs = await SharedPreferences.getInstance();
    // final token = prefs.getString('X-Medsoft-Token') ?? '';
    // final server = prefs.getString('X-Tenant') ?? '';

    // final uri = Uri.parse('${Constants.appUrl}/room/get/driver');

    // final headers = {
    //   'Authorization': 'Bearer $token',
    //   'X-Medsoft-Token': token,
    //   'X-Tenant': server,
    //   'X-Token': Constants.xToken,
    // };

    // final response = await http.get(uri, headers: headers);
    final response = await _mapDAO.getPatientsListAmbulance();

    if (response.success) {
      final json = response.data!;
      setState(() {
        patients = json;
        isLoading = false;
      });
    } else {
      if (initialLoad) {
        setState(() => isLoading = false);
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        _logOut();
      }
    }
  }

  void _logOut() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('X-Tenant');
    await prefs.remove('X-Medsoft-Token');
    await prefs.remove('Username');
    await prefs.remove('scannedToken');
    await prefs.remove('tenantDomain');
    await prefs.remove('forgetUrl');

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
  }

  Future<void> _loadSharedPreferencesData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> data = {};

    Set<String> allKeys = prefs.getKeys();
    for (String key in allKeys) {
      if (key == 'isLoggedIn' || key == 'arrivedInFifty') {
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

  Widget _buildMultilineHTMLText(String value) {
    if (value.isEmpty) {
      return Html(data: '');
    }

    return Html(data: value);
  }

  String _extractLine(String htmlValue, String keyword) {
    if (htmlValue.isEmpty) return '';
    final lines = htmlValue.split('<br>');
    for (final line in lines) {
      if (line.contains(keyword)) {
        return line.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      }
    }
    return '';
  }

  String _extractReceivedShort(String htmlValue) {
    if (htmlValue.isEmpty) return '';
    final lines = htmlValue.split('<br>');
    for (final line in lines) {
      if (line.contains('Хүлээж авсан')) {
        final clean = line.replaceAll(RegExp(r'<[^>]*>'), '').trim();

        final idx = clean.indexOf(RegExp(r'[А-ЯA-Z]\.'));
        return idx > 0 ? clean.substring(0, idx).trim() : clean;
      }
    }
    return '';
  }

  // --- NEW HELPER METHOD 3: Send Message Button ---
  Widget _buildSendMessageButton(BuildContext context, dynamic patient, bool isTablet) {
    final roomId = patient['roomId'];
    final roomIdNum = patient['_id'];
    final phone = patient['patientPhone'];

    final buttonLabel = "Мессеж илгээх";

    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.message, size: 18),
        label: Text(
          buttonLabel,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: isTablet ? 16 : 12),
        ),
        onPressed: () async {
          if (roomId == null || phone == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Room ID эсвэл утасны дугаар олдсонгүй'),
                duration: Duration(seconds: 1),
              ),
            );
            return;
          }

          // final prefs = await SharedPreferences.getInstance();
          // final token = prefs.getString('X-Medsoft-Token') ?? '';
          // final server = prefs.getString('X-Tenant') ?? '';

          // final uri = Uri.parse(
          //   '${Constants.runnerUrl}/gateway/general/get/api/inpatient/ambulance/sendToMedsoftApp?roomId=$roomIdNum&patientPhone=$phone',
          // );

          try {
            // final response = await http.get(
            //   uri,
            //   headers: {
            //     'X-Medsoft-Token': token,
            //     'X-Tenant': server == 'Citizen' ? 'ui.medsoft.care' : server,
            //     'X-Token': Constants.xToken,
            //   },
            // );
            final response = await _mapDAO.sendSmsToPatient(roomId, phone);

            if (response.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Мессеж амжилттай илгээгдлээ'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 1),
                ),
              );
              refreshPatients();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(response.message ?? 'Алдаа гарлаа'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 1),
                ),
              );
              if (response.statusCode == 401 || response.statusCode == 403) {
                _logOut();
              }
            }
          } catch (e) {
            debugPrint('Send SMS error: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Сүлжээний алдаа: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
      ),
    );
  }

  // --- NEW HELPER METHOD 4: Location Button ---
  Widget _buildLocationButton(BuildContext context, dynamic patient, bool isTablet) {
    final patientSent = patient['patientSent'] ?? false;
    final url = patient['url'];
    final title = "Дуудлагын жагсаалт";
    final roomId = patient['roomId'];
    final roomIdNum = patient['_id'];
    final buttonLabel = "Байршил";

    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.location_pin, size: 18),
        label: Text(
          buttonLabel,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: isTablet ? 16 : 12),
        ),
        onPressed:
            patientSent
                ? () async {
                  if (url != null && url.toString().startsWith('http')) {
                    try {
                      await platform.invokeMethod('sendRoomIdToAppDelegate', {'roomId': roomId});
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => WebViewScreen(
                                url: url,
                                title: title,
                                roomId: roomId,
                                roomIdNum: roomIdNum,
                              ),
                        ),
                      );
                    } on PlatformException catch (e) {
                      debugPrint("Failed to start location: $e");
                    }
                  } else {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text("Invalid URL")));
                  }
                }
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final prefs = snapshot.data!;
        final xMedsoftToken = prefs.getString('X-Medsoft-Token') ?? '';
        final tenantDomain = prefs.getString('tenantDomain') ?? '';

        final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

        return Scaffold(
          body:
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                    padding: const EdgeInsets.all(12.0),
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final patient = patients[index];
                      final roomId = patient['roomId'];
                      final arrived = patient['arrived'] ?? false;
                      final distance = patient['totalDistance'] ?? '';
                      final duration = patient['distotalDistancetance'] ?? '';
                      final patientPhone = patient['patientPhone'] ?? '';
                      final patientData = patient['data'] ?? {};
                      final values = patientData['values'] ?? {};

                      String getValue(String key) {
                        if (values[key] != null && values[key]['value'] != null) {
                          return values[key]['value'] as String;
                        }
                        return '';
                      }

                      final patientName = patientData['patientName'] ?? '';
                      final patientRegNo = patientData['patientRegNo'] ?? '';
                      final patientGender = patientData['patientGender'] ?? '';
                      final patientSent = patient['patientSent'] ?? false;

                      final reportedCitizen = getValue('reportedCitizen');
                      final received = getValue('received');
                      final type = getValue('type');
                      final time = getValue('time');
                      final ambulanceTeam = getValue('ambulanceTeam');

                      final address = _extractLine(reportedCitizen, 'Хаяг');
                      final receivedShort = _extractReceivedShort(received);

                      final isExpanded = _expandedTiles.contains(index);

                      // --- DYNAMIC LAYOUT VARIABLES ---
                      final screenWidth = MediaQuery.of(context).size.width;
                      final isNarrowScreen = screenWidth < 500;
                      final isTablet = screenWidth >= 600; // Used for new button font sizing

                      final mainAxisAlignment =
                          isNarrowScreen ? MainAxisAlignment.start : MainAxisAlignment.center;
                      // --------------------------------

                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 700, // Max width for centering on large screens
                          ),
                          child: Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Container(
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  key: PageStorageKey(index),
                                  initiallyExpanded: false,
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 1,
                                  ),
                                  onExpansionChanged: (expanded) {
                                    setState(() {
                                      if (expanded) {
                                        _expandedTiles.add(index);
                                      } else {
                                        _expandedTiles.remove(index);
                                      }
                                    });
                                  },
                                  title: Text(
                                    patientPhone,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!isExpanded && address.isNotEmpty)
                                        Text(address, overflow: TextOverflow.ellipsis, maxLines: 1),
                                      if (!isExpanded && receivedShort.isNotEmpty)
                                        Text(
                                          receivedShort,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: EdgeInsets.only(right: isNarrowScreen ? 0 : 100.0),
                                        child: Row(
                                          mainAxisAlignment: mainAxisAlignment,
                                          children: [
                                            // Button 1: Үзлэг (40% on narrow, content-sized on wide)
                                            isNarrowScreen
                                                ? Expanded(
                                                  flex: 5,
                                                  child: _buildSendMessageButton(
                                                    context,
                                                    patient,
                                                    isTablet,
                                                  ),
                                                )
                                                : Expanded(
                                                  flex: 5,
                                                  child: _buildSendMessageButton(
                                                    context,
                                                    patient,
                                                    isTablet,
                                                  ),
                                                ),

                                            const SizedBox(width: 8),

                                            // Button 2: Баталгаажуулах (60% on narrow, content-sized on wide)
                                            isNarrowScreen
                                                ? Expanded(
                                                  flex: 5,
                                                  child: _buildLocationButton(
                                                    context,
                                                    patient,
                                                    isTablet,
                                                  ),
                                                )
                                                : Expanded(
                                                  flex: 5,
                                                  child: _buildLocationButton(
                                                    context,
                                                    patient,
                                                    isTablet,
                                                  ),
                                                ),
                                          ],

                                          // children: [
                                          //   Flexible(
                                          //     flex: 6,
                                          //     child: SizedBox(
                                          //       height: 48,
                                          //       child: ElevatedButton(
                                          //         onPressed: () async {
                                          //           final roomId = patient['roomId'];
                                          //           final roomIdNum = patient['_id'];
                                          //           final phone = patient['patientPhone'];

                                          //           if (roomId == null || phone == null) {
                                          //             ScaffoldMessenger.of(context).showSnackBar(
                                          //               const SnackBar(
                                          //                 content: Text(
                                          //                   'Room ID эсвэл утасны дугаар олдсонгүй',
                                          //                 ),
                                          //                 duration: Duration(seconds: 1),
                                          //               ),
                                          //             );
                                          //             return;
                                          //           }

                                          //           final prefs =
                                          //               await SharedPreferences.getInstance();
                                          //           final token =
                                          //               prefs.getString('X-Medsoft-Token') ?? '';
                                          //           final server =
                                          //               prefs.getString('X-Tenant') ?? '';

                                          //           final uri = Uri.parse(
                                          //             '${Constants.runnerUrl}/gateway/general/get/api/inpatient/ambulance/sendToMedsoftApp?roomId=$roomIdNum&patientPhone=$phone',
                                          //           );

                                          //           try {
                                          //             final response = await http.get(
                                          //               uri,
                                          //               headers: {
                                          //                 'X-Medsoft-Token': token,
                                          //                 'X-Tenant':
                                          //                     server == 'Citizen'
                                          //                         ? 'ui.medsoft.care'
                                          //                         : server,
                                          //                 'X-Token': Constants.xToken,
                                          //               },
                                          //             );

                                          //             if (response.statusCode == 200) {
                                          //               final json = jsonDecode(response.body);
                                          //               if (json['success'] == true) {
                                          //                 ScaffoldMessenger.of(
                                          //                   context,
                                          //                 ).showSnackBar(
                                          //                   const SnackBar(
                                          //                     content: Text(
                                          //                       'Мессеж амжилттай илгээгдлээ',
                                          //                     ),
                                          //                     backgroundColor: Colors.green,
                                          //                     duration: Duration(seconds: 1),
                                          //                   ),
                                          //                 );
                                          //                 refreshPatients();
                                          //               } else {
                                          //                 ScaffoldMessenger.of(
                                          //                   context,
                                          //                 ).showSnackBar(
                                          //                   SnackBar(
                                          //                     content: Text(
                                          //                       json['message'] ?? 'Алдаа гарлаа',
                                          //                     ),
                                          //                     backgroundColor: Colors.red,
                                          //                     duration: const Duration(seconds: 1),
                                          //                   ),
                                          //                 );
                                          //                 if (response.statusCode == 401 ||
                                          //                     response.statusCode == 403) {
                                          //                   _logOut();
                                          //                 }
                                          //               }
                                          //             } else {
                                          //               ScaffoldMessenger.of(context).showSnackBar(
                                          //                 SnackBar(
                                          //                   content: Text(
                                          //                     'HTTP алдаа: ${response.statusCode}',
                                          //                   ),
                                          //                   backgroundColor: Colors.red,
                                          //                   duration: const Duration(seconds: 1),
                                          //                 ),
                                          //               );
                                          //             }
                                          //           } catch (e) {
                                          //             debugPrint('Send SMS error: $e');
                                          //             ScaffoldMessenger.of(context).showSnackBar(
                                          //               SnackBar(
                                          //                 content: Text('Сүлжээний алдаа: $e'),
                                          //                 backgroundColor: Colors.red,
                                          //                 duration: const Duration(seconds: 1),
                                          //               ),
                                          //             );
                                          //           }
                                          //         },
                                          //         child: const Text(
                                          //           "Мессеж илгээх",
                                          //           textAlign: TextAlign.center,
                                          //         ),
                                          //       ),
                                          //     ),
                                          //   ),
                                          //   const SizedBox(width: 8),
                                          //   Flexible(
                                          //     flex: 4,
                                          //     child: SizedBox(
                                          //       height: 48,
                                          //       child: ElevatedButton(
                                          //         onPressed:
                                          //             patientSent
                                          //                 ? () async {
                                          //                   final url = patient['url'];
                                          //                   final title = "Дуудлагын жагсаалт";
                                          //                   final roomId = patient['roomId'];
                                          //                   final roomIdNum = patient['_id'];
                                          //                   if (url != null &&
                                          //                       url.toString().startsWith('http')) {
                                          //                     try {
                                          //                       await platform.invokeMethod(
                                          //                         'sendRoomIdToAppDelegate',
                                          //                         {'roomId': roomId},
                                          //                       );
                                          //                       Navigator.push(
                                          //                         context,
                                          //                         MaterialPageRoute(
                                          //                           builder:
                                          //                               (context) => WebViewScreen(
                                          //                                 url: url,
                                          //                                 title: title,
                                          //                                 roomId: roomId,
                                          //                                 roomIdNum: roomIdNum,
                                          //                               ),
                                          //                         ),
                                          //                       );
                                          //                     } on PlatformException catch (e) {
                                          //                       debugPrint(
                                          //                         "Failed to start location: $e",
                                          //                       );
                                          //                     }
                                          //                   } else {
                                          //                     ScaffoldMessenger.of(
                                          //                       context,
                                          //                     ).showSnackBar(
                                          //                       const SnackBar(
                                          //                         content: Text("Invalid URL"),
                                          //                       ),
                                          //                     );
                                          //                   }
                                          //                 }
                                          //                 : null,
                                          //         child: const Text(
                                          //           "Байршил",
                                          //           textAlign: TextAlign.center,
                                          //         ),
                                          //       ),
                                          //     ),
                                          //   ),
                                          // ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  childrenPadding: const EdgeInsets.all(16.0),
                                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Иргэн:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Html(
                                      data:
                                          '$patientName | $patientRegNo<br>$patientPhone<br>Хүйс: $patientGender',
                                    ),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'Дуудлага:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    _buildMultilineHTMLText(reportedCitizen),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'Хүлээж авсан:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    _buildMultilineHTMLText(received),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'Ангилал:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    _buildMultilineHTMLText(type),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'Дуудлагын цаг:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    _buildMultilineHTMLText(time),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'ТТ-ийн баг:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    _buildMultilineHTMLText(ambulanceTeam),
                                    const SizedBox(height: 5),
                                    if (arrived) ...[
                                      Text("Distance: ${distance ?? 'N/A'} km"),
                                      Text("Duration: ${duration ?? 'N/A'}"),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        );
      },
    );
  }
}
