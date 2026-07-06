import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/ambulance_model.dart';
import '../services/firestore_service.dart';
import '../widgets/buttons.dart';
import 'register_ambulance_screen.dart';

class MapScreen
    extends
        StatefulWidget {
  const MapScreen({
    super.key,
  });

  @override
  State<
    MapScreen
  >
  createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _initialPosition = LatLng(-1.2858, 36.8200);
  late final MapController _mapController;
  final FirestoreService _firestoreService = FirestoreService();
  List<Ambulance> _ambulances = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _requestLocationPermission();
    _loadAmbulances();
  }

  Future<void> _loadAmbulances() async {
    _firestoreService.streamAvailableAmbulances().listen((ambulances) {
      if (!mounted) return;
      setState(() => _ambulances = ambulances);
    });
  }

  Future<
    void
  >
  _requestLocationPermission() async {
    final status = await Permission.location.request();

    if (!mounted) return;

    if (status.isDenied) {
      // Permissions are denied, but we can still show the map without location
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission denied',
          ),
        ),
      );
    } else if (status.isPermanentlyDenied) {
      // Show a dialog offering to open app settings
      if (!mounted) return;
      showDialog(
        context: context,
        builder:
            (
              BuildContext context,
            ) => AlertDialog(
              title: const Text(
                'Location Permission',
              ),
              content: const Text(
                'Location permission is permanently denied. Would you like to open app settings?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(),
                  child: const Text(
                    'Cancel',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    openAppSettings();
                    Navigator.of(
                      context,
                    ).pop();
                  },
                  child: const Text(
                    'Open Settings',
                  ),
                ),
              ],
            ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green,
                Colors.blue,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'MedLink',
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.medlink',
              ),
              MarkerLayer(
                markers: [
                  for (final ambulance in _ambulances)
                    Marker(
                      point: LatLng(ambulance.lat, ambulance.lng),
                      child: const Icon(Icons.local_hospital, color: Colors.red, size: 32),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'registerFab',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RegisterAmbulanceScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Register'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: const SizedBox(height: 60),
      ),
      floatingActionButton: PhoneButton(
        onPressed: () {},
        heroTag: 'phoneFab',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
