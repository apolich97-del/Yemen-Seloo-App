import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SelooDiagApp());
}

class SelooDiagApp extends StatefulWidget {
  const SelooDiagApp({super.key});

  @override
  State<SelooDiagApp> createState() => _SelooDiagAppState();
}

class _SelooDiagAppState extends State<SelooDiagApp> {
  final List<String> _log = <String>[];
  bool _firebaseOk = false;
  bool _authOk = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    _add('▶ بدء التشخيص...');

    // 1) Firebase init
    try {
      _add('جاري تهيئة Firebase...');
      await Firebase.initializeApp().timeout(const Duration(seconds: 15));
      _firebaseOk = true;
      _add('✓ Firebase OK');
    } catch (e) {
      _add('✗ Firebase فشل: $e');
      if (mounted) setState(() {});
      return;
    }

    // 2) Anonymous sign-in
    try {
      _add('جاري تسجيل الدخول...');
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance
            .signInAnonymously()
            .timeout(const Duration(seconds: 10));
      }
      _authOk = true;
      _add('✓ تسجيل الدخول OK');
    } catch (e) {
      _add('✗ تسجيل الدخول فشل: $e');
    }

    _add('▶ انتهى التشخيص');

    if (mounted) setState(() {});
  }

  void _add(String line) {
    debugPrint('[Seloo] $line');
    if (mounted) setState(() => _log.add(line));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFAF7FF),
        appBar: AppBar(
          backgroundColor: const Color(0xFF7C3AED),
          foregroundColor: Colors.white,
          title: const Text('تشخيص يمن سيلو'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // حالة Firebase
              _statusCard('Firebase', _firebaseOk),
              const SizedBox(height: 8),
              // حالة Auth
              _statusCard('Auth', _authOk),
              const SizedBox(height: 16),
              const Text('السجل:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _log.join('\n'),
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard(String name, bool ok) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ok ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle : Icons.error,
            color: ok ? Colors.green.shade700 : Colors.red.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            '$name: ${ok ? "يعمل" : "فشل"}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: ok ? Colors.green.shade900 : Colors.red.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
