import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ambulance_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Ambulance>> streamAvailableAmbulances() {
    return _db
        .collection('ambulances')
        .where('status', isEqualTo: 'available')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Ambulance.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> registerAmbulance(Ambulance ambulance) async {
    await _db.collection('ambulances').add(ambulance.toMap());
  }
}
