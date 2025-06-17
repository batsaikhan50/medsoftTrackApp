import 'dart:convert';

import 'package:flutter/material.dart';

class PatientListScreen extends StatelessWidget {
  PatientListScreen({super.key});

  String testResponse = '''
{
  "success": true,
  "data": [
    {
      "_id": "684a7eeba21b50928c458fd3",
      "roomId": "d3a4e519-3b8b-49a5-a593-eaac5f9627f4",
      "patientPhone": "99118822",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": false,
      "createdAt": "2025-06-13T11:23:41.312Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/d3a4e519-3b8b-49a5-a593-eaac5f9627f4/app",
      "patientSent": false
    },
    {
      "_id": "684a7eeba21b50928c458fd4",
      "roomId": "b1cbd2ea-dfa1-41c6-bb95-fc12f409964a",
      "patientPhone": "88557766",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": true,
      "createdAt": "2025-06-14T08:44:11.210Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/b1cbd2ea-dfa1-41c6-bb95-fc12f409964a/app",
      "patientSent": true
    },
    {
      "_id": "684a7eeba21b50928c458fd5",
      "roomId": "9a7e8fb0-42fc-466c-9262-39d1f210c6f1",
      "patientPhone": "88224455",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": false,
      "createdAt": "2025-06-13T06:20:19.818Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/9a7e8fb0-42fc-466c-9262-39d1f210c6f1/app",
      "patientSent": false
    },
    {
      "_id": "684a7eeba21b50928c458fd6",
      "roomId": "cd68abf5-6a26-4d9c-87d2-352bf5c7727d",
      "patientPhone": "99001122",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": true,
      "createdAt": "2025-06-12T14:52:33.105Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/cd68abf5-6a26-4d9c-87d2-352bf5c7727d/app",
      "patientSent": true
    },
    {
      "_id": "684a7eeba21b50928c458fd7",
      "roomId": "fe509b2e-0402-4e94-8a2e-3cce9d041ef6",
      "patientPhone": "88117733",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": false,
      "createdAt": "2025-06-15T09:11:45.999Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/fe509b2e-0402-4e94-8a2e-3cce9d041ef6/app",
      "patientSent": false
    },
    {
      "_id": "684a7eeba21b50928c458fd8",
      "roomId": "70b9fc02-0d6f-47ab-91b0-37bb7f278735",
      "patientPhone": "88774411",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": true,
      "createdAt": "2025-06-13T17:09:27.100Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/70b9fc02-0d6f-47ab-91b0-37bb7f278735/app",
      "patientSent": true
    },
    {
      "_id": "684a7eeba21b50928c458fd9",
      "roomId": "a3e75c3d-d3a5-4dc9-9b55-6b6fdc5f7e76",
      "patientPhone": "88009911",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": false,
      "createdAt": "2025-06-16T10:45:19.288Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/a3e75c3d-d3a5-4dc9-9b55-6b6fdc5f7e76/app",
      "patientSent": false
    },
    {
      "_id": "684a7eeba21b50928c458fda",
      "roomId": "241d3645-0c5e-41a2-a0f5-0b4c02a2098f",
      "patientPhone": "88889900",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": true,
      "createdAt": "2025-06-15T06:31:48.454Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/241d3645-0c5e-41a2-a0f5-0b4c02a2098f/app",
      "patientSent": true
    },
    {
      "_id": "684a7eeba21b50928c458fdb",
      "roomId": "adcf6bcd-c2dc-4412-a08c-bd2d6477c830",
      "patientPhone": "88112244",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": true,
      "createdAt": "2025-06-14T11:01:00.555Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/adcf6bcd-c2dc-4412-a08c-bd2d6477c830/app",
      "patientSent": true
    },
    {
      "_id": "684a7eeba21b50928c458fdc",
      "roomId": "3be58b55-7ac9-42f2-b12f-5b2cb314cc09",
      "patientPhone": "88663322",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": false,
      "createdAt": "2025-06-14T18:22:59.786Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/3be58b55-7ac9-42f2-b12f-5b2cb314cc09/app",
      "patientSent": false
    },
    {
      "_id": "684a7eeba21b50928c458fdd",
      "roomId": "5f4a49d6-88b5-4dd5-a189-09c75a0ab51b",
      "patientPhone": "88335577",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": true,
      "createdAt": "2025-06-16T13:35:14.310Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/5f4a49d6-88b5-4dd5-a189-09c75a0ab51b/app",
      "patientSent": true
    },
    {
      "_id": "684a7eeba21b50928c458fde",
      "roomId": "9cbb4a33-4f9e-4a8e-b6be-04a1446cf2c7",
      "patientPhone": "88008800",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": false,
      "createdAt": "2025-06-13T16:03:23.789Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/9cbb4a33-4f9e-4a8e-b6be-04a1446cf2c7/app",
      "patientSent": false
    },
    {
      "_id": "684a7eeba21b50928c458fdf",
      "roomId": "cfa7bce2-5c77-49ab-a5a5-946d3bfb3185",
      "patientPhone": "88770099",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": true,
      "createdAt": "2025-06-12T20:45:39.921Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/cfa7bce2-5c77-49ab-a5a5-946d3bfb3185/app",
      "patientSent": true
    },
    {
      "_id": "684a7eeba21b50928c458fe0",
      "roomId": "bd356f35-279c-4bc9-bc9c-899e67ef8394",
      "patientPhone": "88443355",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": false,
      "createdAt": "2025-06-17T07:12:59.611Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/bd356f35-279c-4bc9-bc9c-899e67ef8394/app",
      "patientSent": false
    },
    {
      "_id": "684a7eeba21b50928c458fe1",
      "roomId": "2f4d12a6-e11b-4fc1-9fc1-d2d46c3b73f4",
      "patientPhone": "88221166",
      "serverName": "ui.medsoft.care",
      "serverFullName": "UI medsoft hospital agency",
      "sentToPatient": true,
      "createdAt": "2025-06-15T22:51:45.000Z",
      "__v": 0,
      "url": "https://app-ui.medsoft.care/2f4d12a6-e11b-4fc1-9fc1-d2d46c3b73f4/app",
      "patientSent": true
    }
  ]
}
''';

  @override
  Widget build(BuildContext context) {
    final parsedJson = jsonDecode(testResponse);
    final List<dynamic> dataList = parsedJson['data'];

    return Scaffold(
      appBar: AppBar(title: const Text('Patient List')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: dataList.length,
        itemBuilder: (context, index) {
          final patient = dataList[index];

          final patientPhone = patient['patientPhone'] ?? 'Unknown';
          final sentToPatient = patient['sentToPatient'] ?? false;
          final patientSent = patient['patientSent'] ?? false;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
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
                    onPressed: sentToPatient ? null : () {},
                    child: const Text("Send SMS"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: patientSent ? () {} : null,
                    child: const Text("See Map"),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
