import 'package:flutter/material.dart';

import '../models/ambulance_model.dart';
import '../models/request_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _statusMessage = 'Tap the button to create sample Firestore data';

  Future<void> _createSampleRecords() async {
    setState(() => _statusMessage = 'Creating sample records...');

    try {
      final userId = await _firestoreService.createUser(
        UserModel(
          id: 'user-demo-001',
          fullName: 'Test Patient',
          phone: '0712345678',
          role: 'patient',
          email: 'patient@example.com',
          address: 'Nairobi',
          createdAt: DateTime.now(),
        ),
      );

      final ambulanceId = await _firestoreService.createAmbulance(
        Ambulance(
          id: 'ambulance-demo-001',
          name: 'MedLink Alpha',
          plateNumber: 'KCA 123A',
          driverName: 'Jane Mwangi',
          phone: '0700000001',
          status: 'available',
          lat: -1.2865,
          lng: 36.8195,
        ),
      );

      final requestId = await _firestoreService.createRequest(
        RequestModel(
          id: 'request-demo-001',
          patientId: userId,
          patientName: 'Test Patient',
          ambulanceId: ambulanceId,
          status: 'pending',
          locationName: 'Nairobi CBD',
          lat: -1.2865,
          lng: 36.8195,
          createdAt: DateTime.now(),
        ),
      );

      setState(() {
        _statusMessage =
            'Success! Created user: $userId\nambulance: $ambulanceId\nrequest: $requestId';
      });
    } catch (error) {
      setState(() {
        _statusMessage = 'Write failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Data Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _createSampleRecords,
                child: const Text('Create Sample Firestore Data'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
