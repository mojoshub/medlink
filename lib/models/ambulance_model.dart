import 'package:cloud_firestore/cloud_firestore.dart';

class Ambulance {
  final String id;
  final String name;
  final String plateNumber;
  final String driverName;
  final String phone;
  final String status;
  final double lat;
  final double lng;

  Ambulance({
    required this.id,
    required this.name,
    required this.plateNumber,
    required this.driverName,
    required this.phone,
    required this.status,
    required this.lat,
    required this.lng,
  });

  factory Ambulance.fromMap(String id, Map<String, dynamic> map) {
    return Ambulance(
      id: id,
      name: map['name']?.toString() ?? '',
      plateNumber: map['plateNumber']?.toString() ?? '',
      driverName: map['driverName']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      status: map['status']?.toString() ?? 'offline',
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'plateNumber': plateNumber,
        'driverName': driverName,
        'phone': phone,
        'status': status,
        'lat': lat,
        'lng': lng,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
}
