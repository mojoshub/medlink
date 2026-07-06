import '../models/ambulance_model.dart';

class FirestoreService {
  Stream<List<Ambulance>> streamAvailableAmbulances() {
    final demoAmbulances = [
      Ambulance(
        id: 'demo-1',
        name: 'MedLink Alpha',
        plateNumber: 'KCA 123A',
        driverName: 'Jane Mwangi',
        phone: '0700000001',
        status: 'available',
        lat: -1.2865,
        lng: 36.8195,
      ),
      Ambulance(
        id: 'demo-2',
        name: 'MedLink Beta',
        plateNumber: 'KCB 456B',
        driverName: 'Peter Otieno',
        phone: '0700000002',
        status: 'available',
        lat: -1.2878,
        lng: 36.8220,
      ),
    ];

    return Stream.value(demoAmbulances);
  }

  Future<void> registerAmbulance(Ambulance ambulance) async {
    // Demo mode: no-op so the app can still run locally.
  }
}
