# Ambulance Rider App — Final Year Project Plan
**Stack:** Flutter/Dart (Android only) · Firebase (Auth + Firestore) · OpenStreetMap via `flutter_map` · Straight-line distance/ETA · Simulated ambulance movement

---

## 1. Assumptions & Scope (write these into your report as "scope limitations")

**Core scope**
- One rider app only. No separate driver app — one ambulance is simulated (its Firestore location is updated by a timer following a hardcoded route).
- Distance/ETA is straight-line (Haversine formula) with an assumed average speed, not real road routing. This is a reasonable, clearly-stated simplification for a demo.
- "Registering an ambulance" is a **first-class page in the app's navigation** — not a hidden debug route and not a manual Firestore console entry. It's a real screen with a form, validation, and a save action that writes a new `ambulances` document. This gives you a genuine CRUD feature to demo live and to document in your report.

**Firestore security — what "code implementation" actually means here**
Security isn't just a rules file you write once at the end — it affects how you structure reads/writes throughout the app, so plan for it from Day 1:
- Every write (registering an ambulance, creating a request, updating status) must happen through an **authenticated** session — even anonymous auth gives you a stable `uid` to scope rules against, so make sure sign-in happens before any Firestore call is possible in the UI (guard routes/screens behind an auth check, don't just hide the button).
- A rider should only be able to **read/update their own `requests` documents** (matched by `riderId == request.auth.uid`), not any other rider's request — this is enforced in the rules, not just by hiding UI.
- Ambulance documents are readable by any authenticated user (riders need to see them on the map), but for the demo, writes are also left open to any authenticated user, since your simulator and registration screen both write as a normal signed-in user rather than a separate driver/admin role. **State this explicitly as a known limitation** in your report — see the full rules and hardening notes in Section 3.
- Because there's no separate backend server validating business logic (e.g. "can't request an ambulance that's already busy"), that validation has to happen **client-side in your `RequestProvider`/service layer** before writing to Firestore. Note in your report that a production system would move this into Cloud Functions or a backend so a malicious client can't bypass it.
- Keep `google-services.json` out of version control screenshots in your report if it contains your real Firebase project keys (it's fine to commit into your private repo — Firebase's client keys aren't secret in the way API secret keys are — but don't paste it into a public appendix).

---

## 2. System Architecture

Layered, MVVM-ish structure — easy to explain in a viva:

```
UI (Screens/Widgets)
   ↓ calls
Providers (ChangeNotifier — app state, business logic glue)
   ↓ calls
Services (Auth, Firestore, Location, Distance, Simulator)
   ↓ talks to
Firebase (Firestore + Auth)
```

### Folder structure

```
lib/
 ├─ main.dart
 ├─ models/
 │   ├─ ambulance_model.dart
 │   ├─ request_model.dart
 │   └─ app_user_model.dart
 ├─ services/
 │   ├─ auth_service.dart
 │   ├─ firestore_service.dart
 │   ├─ location_service.dart
 │   ├─ distance_service.dart
 │   └─ ambulance_simulator_service.dart
 ├─ providers/
 │   ├─ auth_provider.dart
 │   ├─ ambulance_provider.dart
 │   └─ request_provider.dart
 ├─ screens/
 │   ├─ splash_screen.dart
 │   ├─ auth/login_screen.dart
 │   ├─ home/home_map_screen.dart
 │   ├─ request/request_confirm_screen.dart
 │   ├─ request/tracking_screen.dart
 │   └─ register/register_ambulance_screen.dart   // real nav page, not a hidden admin route
 ├─ widgets/
 │   ├─ ambulance_marker.dart
 │   ├─ nearest_ambulance_card.dart
 │   └─ custom_button.dart
 └─ utils/
     ├─ constants.dart
     └─ haversine.dart
```

State management: **Provider** (ChangeNotifier). It's simple to justify in a viva and doesn't add the overhead of Bloc/Riverpod for a 2-week solo build.

---

## 3. Firestore Data Model

**Collection: `ambulances`**
```
ambulances/{ambulanceId}
  name: "Ambulance 01"
  plateNumber: "AB-123-CD"
  driverName: "John Doe"
  phone: "+31612345678"        // used for the "call" button
  status: "available" | "busy" | "offline"
  lat: 52.3702
  lng: 4.8952
  lastUpdated: Timestamp
```

**Collection: `requests`**
```
requests/{requestId}
  riderId: "uid_xxx"
  riderName: "Jane Rider"
  riderPhone: "+31698765432"
  pickupLat: 52.3676
  pickupLng: 4.9041
  ambulanceId: "ambulanceId"
  status: "pending" | "accepted" | "completed" | "cancelled"
  createdAt: Timestamp
```

**Collection: `users`** (optional, minimal profile)
```
users/{uid}
  name, phone, createdAt
```

### Firestore rules — demo-appropriate, not wide-open

This is a step up from a blanket "test mode" rule: it's still permissive enough to build against in two weeks, but it's scoped per-collection so you can honestly say in your report that access control was considered, not skipped.

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Riders can only read/write their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Any authenticated user (rider, or the simulator/registration screen
    // acting as a signed-in user) can read and write ambulances.
    // KNOWN LIMITATION: there's no separate "driver" role in this prototype —
    // see hardening notes below.
    match /ambulances/{ambulanceId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }

    // A rider can create a request for themself, and read/update
    // only requests they own.
    match /requests/{requestId} {
      allow create: if request.auth != null
                     && request.resource.data.riderId == request.auth.uid;
      allow read, update: if request.auth != null
                           && resource.data.riderId == request.auth.uid;
    }
  }
}
```

**Hardening notes to include in your report's "Future Work":**
- Introduce a custom claim or a `role` field (`rider` / `driver` / `admin`) set via a trusted process (e.g. Cloud Function), and restrict `ambulances` writes to `role == 'driver'` or `role == 'admin'`.
- Validate state transitions server-side (e.g. a request can only move `pending → accepted → completed`, and an ambulance can't be assigned if it's already `busy`) using Cloud Functions, since Firestore rules alone can't easily express full workflow logic.
- Rate-limit or validate the fields being written (e.g. `lat`/`lng` are numbers within valid ranges) using `request.resource.data` checks in the rules.
- For the demo, you can deploy these rules from the Firebase Console → Firestore → Rules tab, or via the Firebase CLI (`firebase deploy --only firestore:rules`) once you have `firebase-tools` installed and the project initialized (`firebase init firestore`).

---

## 4. Screens & User Flow

1. **Splash → Auth** — Firebase Auth. Use **anonymous auth + a simple name/phone capture form** stored in `users/{uid}`. This avoids SMS/OTP setup complexity within your timeline. (Stretch goal: real phone auth if time remains.)
2. **Home / Map Screen** — `flutter_map` with OSM tiles, shows rider's live location (via `geolocator`), streams `ambulances` where `status == "available"`, plots markers, computes distance to each via Haversine, shows a card for the nearest one with distance + estimated ETA.
3. **Request Confirm Screen** — Shows nearest ambulance details, "Request Ambulance" button → creates a `requests` doc, sets that ambulance's `status` to `"busy"`.
4. **Tracking Screen** — Streams the assigned ambulance's live location doc (updated by the simulator), redraws its marker as it "moves," recalculates distance/ETA every update, shows a **Call Ambulance** button.
5. **Register Ambulance Screen** — a real, reachable page in your app's navigation (e.g. a menu item or a tab, not a hidden dev route). A form (name, plate number, driver name, phone, starting lat/lng, initial status) with basic validation (required fields, phone format, lat/lng ranges) that writes a new doc to `ambulances`. This is your literal "register at least one ambulance" feature — demo it live, and it doubles as your CRUD "create" example in your report.
6. **Cancel / Complete** — On cancel or completion, reset ambulance `status` back to `"available"` and update the request doc.

---

## 5. Distance & ETA Logic

Haversine formula (straight-line distance between two lat/lng points), then ETA = distance ÷ assumed average speed (e.g. 40 km/h urban — make this a constant you can tune and explain as an assumption).

---

## 6. Ambulance Simulation Plan

Since there's no driver app, movement is simulated **inside the same Flutter project** (keeps you to "Flutter/Dart only"):

- Define a hardcoded list of `LatLng` waypoints (e.g., a route near your city/campus — grab points off OpenStreetMap or just interpolate between two coordinates).
- A `Timer.periodic` (every 3–5 seconds) advances to the next waypoint and writes `lat`/`lng`/`lastUpdated` to that ambulance's Firestore doc.
- Run this simulator either:
  - as a **hidden debug button** in the app itself (simplest — one phone runs the rider app, a second emulator/phone runs the same app in "simulator mode"), or
  - as a small **second Flutter entry point** (`main_simulator.dart`) you launch separately during the demo.
- For your presentation: run the rider app on your phone and the simulator on an emulator side-by-side, so the examiners visually see the ambulance marker move and the ETA count down in real time.

---

## 7. Call Feature (no driver app needed here)

Use `url_launcher` with a `tel:` URI. This opens the native dialer pre-filled with the number (`ACTION_DIAL`), which does **not** require the `CALL_PHONE` runtime permission — matches your requirement of "navigate to the phone app."

---

## 8. Permissions (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```
(No `CALL_PHONE` needed since you're using `tel:` dial-intent, not direct call.)

---

## 9. Two-Week Day-by-Day Plan

You already have a basic button UI and a map screen — Days 1–2 will move fast.

### Week 1 — Foundation & core matching
- **Day 1:** Create Firebase project, add Android app, drop in `google-services.json`, add all dependencies to `pubspec.yaml`, initialize Firebase in `main.dart`, set up folder structure and git repo. Deploy the scoped Firestore security rules from Section 3 (not the default test-mode rule) so every screen you build afterward is already working against real access control instead of needing a rules rewrite later.
- **Day 2:** Define model classes (`Ambulance`, `RequestModel`, `AppUser`). Build the **Register Ambulance** page (a real navigable screen, with form validation) and use it to create your first ambulance doc — this is your "register at least one ambulance" milestone, done in week 1, and it's the screen you'll demo first to show a working feature end-to-end.
- **Day 3:** Firebase Auth — anonymous sign-in + name/phone capture screen, saved to `users/{uid}`.
- **Day 4:** Wire up `flutter_map` on the Home screen with OSM tiles; get the rider's live location via `geolocator` with proper permission handling.
- **Day 5:** Stream `ambulances` (status == available) from Firestore, plot markers, implement the Haversine distance service, show nearest-ambulance card.
- **Day 6:** Build the "Request Ambulance" flow: create request doc, flip ambulance status to busy, navigate to the tracking screen.
- **Day 7:** Buffer day — fix bugs from week 1, write up progress notes for your report while it's fresh.

### Week 2 — Simulation, live tracking, call, polish
- **Day 8:** Build the ambulance movement simulator (hardcoded waypoints + `Timer.periodic` writing to Firestore).
- **Day 9:** Build the Tracking screen: `StreamBuilder` on the assigned ambulance doc, live marker updates, recalculated distance/ETA on every tick, status text ("Ambulance en route — 3.2 km away").
- **Day 10:** Add the Call button (`url_launcher` + `tel:`), test on a real Android device (emulators can't place calls but will open the dialer).
- **Day 11:** Cancel/complete flow + edge cases (no ambulance available, request already taken, etc.).
- **Day 12:** UI/UX polish — consistent theme/colors, loading states, empty states, app icon, splash screen.
- **Day 13:** Full test pass on a physical Android device; fix permission edge cases; write your demo script (which device does what).
- **Day 14:** Final buffer — rehearse the live demo, record a backup screen-capture video in case live Wi-Fi/demo fails, finish report/slides.

---

## 10. Key Package Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^latest
  firebase_auth: ^latest
  cloud_firestore: ^latest
  flutter_map: ^latest
  latlong2: ^latest
  geolocator: ^latest
  url_launcher: ^latest
  provider: ^latest
```
Run `flutter pub add <package>` for each so you always get a resolvable, current version rather than a pinned number that may already be stale.

---

## 11. Code Skeletons

### `models/ambulance_model.dart`
```dart
class Ambulance {
  final String id;
  final String name;
  final String plateNumber;
  final String driverName;
  final String phone;
  final String status; // available | busy | offline
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
      name: map['name'] ?? '',
      plateNumber: map['plateNumber'] ?? '',
      driverName: map['driverName'] ?? '',
      phone: map['phone'] ?? '',
      status: map['status'] ?? 'offline',
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
        'lastUpdated': DateTime.now(),
      };
}
```

### `utils/haversine.dart`
```dart
import 'dart:math';

class DistanceService {
  static const double earthRadiusKm = 6371;
  static const double assumedSpeedKmh = 40; // stated assumption for report

  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180);

  static Duration etaFor(double distanceKm) {
    final hours = distanceKm / assumedSpeedKmh;
    return Duration(seconds: (hours * 3600).round());
  }
}
```

### `services/firestore_service.dart`
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ambulance_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Ambulance>> streamAvailableAmbulances() {
    return _db
        .collection('ambulances')
        .where('status', isEqualTo: 'available')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Ambulance.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<Ambulance> streamAmbulance(String id) {
    return _db.collection('ambulances').doc(id).snapshots().map(
        (doc) => Ambulance.fromMap(doc.id, doc.data()!));
  }

  Future<void> registerAmbulance(Ambulance amb) {
    return _db.collection('ambulances').doc().set(amb.toMap());
  }

  Future<String> createRequest(Map<String, dynamic> requestData) async {
    final doc = await _db.collection('requests').add(requestData);
    return doc.id;
  }

  Future<void> setAmbulanceStatus(String ambulanceId, String status) {
    return _db.collection('ambulances').doc(ambulanceId).update({'status': status});
  }
}
```

### `services/ambulance_simulator_service.dart`
```dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class AmbulanceSimulatorService {
  Timer? _timer;
  int _index = 0;

  // Replace with real coordinates around your demo area
  final List<Map<String, double>> route = [
    {'lat': 52.3702, 'lng': 4.8952},
    {'lat': 52.3680, 'lng': 4.9000},
    {'lat': 52.3660, 'lng': 4.9050},
    {'lat': 52.3640, 'lng': 4.9100},
  ];

  void start(String ambulanceId) {
    _timer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final point = route[_index % route.length];
      await FirebaseFirestore.instance
          .collection('ambulances')
          .doc(ambulanceId)
          .update({
        'lat': point['lat'],
        'lng': point['lng'],
        'lastUpdated': DateTime.now(),
      });
      _index++;
    });
  }

  void stop() => _timer?.cancel();
}
```

### `screens/home/home_map_screen.dart` (core structure)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/firestore_service.dart';
import '../../utils/haversine.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});
  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final _firestoreService = FirestoreService();
  Position? _myPosition;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    final pos = await Geolocator.getCurrentPosition();
    setState(() => _myPosition = pos);
  }

  @override
  Widget build(BuildContext context) {
    if (_myPosition == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: StreamBuilder(
        stream: _firestoreService.streamAvailableAmbulances(),
        builder: (context, snapshot) {
          final ambulances = snapshot.data ?? [];
          return FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(_myPosition!.latitude, _myPosition!.longitude),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourname.ambulanceapp',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: LatLng(_myPosition!.latitude, _myPosition!.longitude),
                  child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 36),
                ),
                for (final amb in ambulances)
                  Marker(
                    point: LatLng(amb.lat, amb.lng),
                    child: const Icon(Icons.local_hospital, color: Colors.red, size: 36),
                  ),
              ]),
            ],
          );
        },
      ),
    );
  }
}
```

### `screens/register/register_ambulance_screen.dart` (first-class page, not a hidden route)
```dart
import 'package:flutter/material.dart';
import '../../models/ambulance_model.dart';
import '../../services/firestore_service.dart';

class RegisterAmbulanceScreen extends StatefulWidget {
  const RegisterAmbulanceScreen({super.key});
  @override
  State<RegisterAmbulanceScreen> createState() => _RegisterAmbulanceScreenState();
}

class _RegisterAmbulanceScreenState extends State<RegisterAmbulanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  final _nameCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _driverCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ambulance = Ambulance(
      id: '', // Firestore assigns this
      name: _nameCtrl.text.trim(),
      plateNumber: _plateCtrl.text.trim(),
      driverName: _driverCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      status: 'available',
      lat: double.parse(_latCtrl.text.trim()),
      lng: double.parse(_lngCtrl.text.trim()),
    );

    await _firestoreService.registerAmbulance(ambulance);

    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ambulance registered successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Ambulance')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Ambulance Name'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _plateCtrl,
              decoration: const InputDecoration(labelText: 'Plate Number'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _driverCtrl,
              decoration: const InputDecoration(labelText: 'Driver Name'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone Number (e.g. +316...)'),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || !v.startsWith('+')) ? 'Include country code, e.g. +316...' : null,
            ),
            TextFormField(
              controller: _latCtrl,
              decoration: const InputDecoration(labelText: 'Starting Latitude'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              validator: (v) {
                final d = double.tryParse(v ?? '');
                if (d == null || d < -90 || d > 90) return 'Enter a valid latitude (-90 to 90)';
                return null;
              },
            ),
            TextFormField(
              controller: _lngCtrl,
              decoration: const InputDecoration(labelText: 'Starting Longitude'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              validator: (v) {
                final d = double.tryParse(v ?? '');
                if (d == null || d < -180 || d > 180) return 'Enter a valid longitude (-180 to 180)';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Register Ambulance'),
            ),
          ],
        ),
      ),
    );
  }
}
```
Wire this into your app's main navigation (e.g. a bottom nav tab, a drawer item, or a button on the Home screen) so it's a page anyone can reach — not just something you trigger from debug code.

### Call button (in `tracking_screen.dart`)
```dart
import 'package:url_launcher/url_launcher.dart';

Future<void> callAmbulance(String phoneNumber) async {
  final uri = Uri(scheme: 'tel', path: phoneNumber);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

// usage:
ElevatedButton.icon(
  onPressed: () => callAmbulance(ambulance.phone),
  icon: const Icon(Icons.call),
  label: const Text('Call Ambulance'),
)
```

---

## 12. Demo Day Setup

- **Device A (your phone):** the rider app — shows map, requests, tracking, call button.
- **Device B (emulator or second phone):** same app, but tap into "simulator mode" (a hidden debug button on a settings screen) to start `AmbulanceSimulatorService`.
- Walk through: register ambulance (if not pre-seeded) → open rider app → see marker on map → request → watch it move on Device A as Device B's timer ticks → tap Call → dialer opens.
- Record a backup video of this full flow in advance, in case live Wi-Fi/Firebase connectivity fails during presentation.

---

## 13. Stretch Goals (only if time remains)

- Replace anonymous auth with real phone-number OTP auth.
- Add OSRM-based turn-by-turn routing instead of straight-line ETA.
- Add a request history screen.
- Add `geoflutterfire`/geohash queries if you want to demonstrate scaling to many ambulances.

---

## 14. Where You Can Make This Your Own

Everything above is a settled foundation — architecture, data model, security rules, and code skeletons are ready to build on as-is. The list below is the opposite: places intentionally left open so you can adjust them to your taste, your demo location, or feedback from your supervisor, **without** needing to change anything else in the plan.

| Area | What's fixed | What you can freely change |
|---|---|---|
| Simulated route | The mechanism (`Timer.periodic` writing lat/lng to Firestore) | The actual waypoints, tick interval, and number of stops — pick real coordinates near your demo location |
| Assumed speed | The formula (`distance ÷ speed = ETA`) | The `assumedSpeedKmh` constant — tune it so ETAs look realistic for your city |
| Auth method | Firebase Auth is the provider | Anonymous vs. email/password vs. real phone OTP — anonymous is fastest to build, but swapping it later only touches `auth_service.dart` and the login screen |
| Registration screen fields | It's a real page that writes to `ambulances` | Add/remove fields (e.g. ambulance type, hospital affiliation, capacity) — just extend the `Ambulance` model and the form |
| Visual design | Screens, navigation flow, and data flow | Colors, fonts, icons, layout, branding — none of this affects the architecture |
| Number of ambulances | The query logic supports any number | You can register more than one ambulance and run multiple simulators to make the "closest ambulance" logic visibly meaningful in the demo, if you have time |
| Security rules | The per-collection structure and the `riderId`-ownership pattern | You can add stricter role checks later (see hardening notes in Section 3) without restructuring the app |

If you make a change in one of these areas, it should be a **local edit** — you shouldn't need to touch the provider/service layering, the Firestore schema shape, or the screen flow to accommodate it.

---

## Report-writing tip
Frame the straight-line ETA, single simulated ambulance, and anonymous auth explicitly as **scoped design decisions for a functional prototype**, with a "Future Work" section listing real routing, multiple live drivers, and OTP auth. Examiners respond well to clearly stated scope rather than an app that silently cuts corners.
