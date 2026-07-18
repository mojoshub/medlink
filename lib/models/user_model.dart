import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String fullName;
  final String phone;
  final String role;
  final String? email;
  final String? address;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.email,
    this.address,
    required this.createdAt,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      fullName: map['fullName']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      role: map['role']?.toString() ?? 'patient',
      email: map['email']?.toString(),
      address: map['address']?.toString(),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'phone': phone,
        'role': role,
        'email': email,
        'address': address,
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
