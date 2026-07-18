import 'package:cloud_firestore/cloud_firestore.dart';

class RequestModel {
  final String id;
  final String patientId;
  final String patientName;
  final String ambulanceId;
  final String status;
  final String locationName;
  final double lat;
  final double lng;
  final DateTime createdAt;

  RequestModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.ambulanceId,
    required this.status,
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.createdAt,
  });

  factory RequestModel.fromMap(String id, Map<String, dynamic> map) {
    return RequestModel(
      id: id,
      patientId: map['patientId']?.toString() ?? '',
      patientName: map['patientName']?.toString() ?? '',
      ambulanceId: map['ambulanceId']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      locationName: map['locationName']?.toString() ?? '',
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'patientName': patientName,
        'ambulanceId': ambulanceId,
        'status': status,
        'locationName': locationName,
        'lat': lat,
        'lng': lng,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
