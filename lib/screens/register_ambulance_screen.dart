import 'package:flutter/material.dart';
import '../models/ambulance_model.dart';
import '../services/firestore_service.dart';

class RegisterAmbulanceScreen extends StatefulWidget {
  const RegisterAmbulanceScreen({super.key});

  @override
  State<RegisterAmbulanceScreen> createState() => _RegisterAmbulanceScreenState();
}

class _RegisterAmbulanceScreenState extends State<RegisterAmbulanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final _driverController = TextEditingController();
  final _phoneController = TextEditingController();
  final _latController = TextEditingController(text: '-1.2858');
  final _lngController = TextEditingController(text: '36.8200');
  bool _saving = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    final ambulance = Ambulance(
      id: '',
      name: _nameController.text.trim(),
      plateNumber: _plateController.text.trim(),
      driverName: _driverController.text.trim(),
      phone: _phoneController.text.trim(),
      status: 'available',
      lat: double.parse(_latController.text.trim()),
      lng: double.parse(_lngController.text.trim()),
    );

    await _firestoreService.registerAmbulance(ambulance);

    if (!mounted) return;

    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ambulance registered successfully')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Ambulance'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Ambulance Name'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plateController,
              decoration: const InputDecoration(labelText: 'Plate Number'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _driverController,
              decoration: const InputDecoration(labelText: 'Driver Name'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                if (!value.startsWith('+')) {
                  return 'Include country code, e.g. +254...';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _latController,
              decoration: const InputDecoration(labelText: 'Starting Latitude'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed < -90 || parsed > 90) {
                  return 'Enter a valid latitude';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lngController,
              decoration: const InputDecoration(labelText: 'Starting Longitude'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed < -180 || parsed > 180) {
                  return 'Enter a valid longitude';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.local_hospital),
              label: Text(_saving ? 'Saving...' : 'Register Ambulance'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _driverController.dispose();
    _phoneController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }
}
