import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../firebase_options.dart';
import 'map_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0.0;
  String _status = 'Starting MedLink...';
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  Future<void> _startLoading() async {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_progress < 0.9) {
        setState(() => _progress += 0.05);
      }
    });

    try {
      await dotenv.load();
      setState(() => _status = 'Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (!mounted) return;

      setState(() {
        _status = 'Finalizing startup...';
        _progress = 0.95;
      });
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      _progressTimer?.cancel();
      setState(() => _progress = 1.0);
      await Future.delayed(const Duration(milliseconds: 250));

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MapScreen(),
        ),
      );
    } catch (error) {
      _progressTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _status = 'Startup failed: $error';
        _progress = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'ambulance.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 32),
                const Text(
                  'MedLink',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
