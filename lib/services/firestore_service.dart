import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ambulance_model.dart';
import '../models/request_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _ambulancesRef =>
      _firestore.collection('ambulances');

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection('requests');

  Stream<List<Ambulance>> streamAvailableAmbulances() {
    return _ambulancesRef.where('status', isEqualTo: 'available').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Ambulance.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> registerAmbulance(Ambulance ambulance) async {
    await _ambulancesRef.doc(ambulance.id).set(ambulance.toMap());
  }

  Future<String> createUser(UserModel user) async {
    if (user.id.isNotEmpty) {
      await _usersRef.doc(user.id).set(user.toMap());
      return user.id;
    }

    final docRef = await _usersRef.add(user.toMap());
    return docRef.id;
  }

  Future<String> createAmbulance(Ambulance ambulance) async {
    if (ambulance.id.isNotEmpty) {
      await _ambulancesRef.doc(ambulance.id).set(ambulance.toMap());
      return ambulance.id;
    }

    final docRef = await _ambulancesRef.add(ambulance.toMap());
    return docRef.id;
  }

  Future<String> createRequest(RequestModel request) async {
    if (request.id.isNotEmpty) {
      await _requestsRef.doc(request.id).set(request.toMap());
      return request.id;
    }

    final docRef = await _requestsRef.add(request.toMap());
    return docRef.id;
  }

  Future<List<UserModel>> getUsers() async {
    final snapshot = await _usersRef.orderBy('createdAt').get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<Ambulance>> getAmbulances() async {
    final snapshot = await _ambulancesRef.orderBy('lastUpdated').get();
    return snapshot.docs
        .map((doc) => Ambulance.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<RequestModel>> getRequests() async {
    final snapshot = await _requestsRef.orderBy('createdAt').get();
    return snapshot.docs
        .map((doc) => RequestModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> updateAmbulanceLocation({
    required String ambulanceId,
    required double lat,
    required double lng,
    required String status,
  }) async {
    await _ambulancesRef.doc(ambulanceId).update({
      'lat': lat,
      'lng': lng,
      'status': status,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
  }) async {
    await _requestsRef.doc(requestId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
