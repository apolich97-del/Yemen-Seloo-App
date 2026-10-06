import 'package:flutter/material.dart';

void main() {
  runApp(const SelooTestApp());
}

class SelooTestApp extends StatelessWidget {
  const SelooTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF7C3AED),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const <Widget>[
              Icon(Icons.check_circle, color: Colors.white, size: 100),
              SizedBox(height: 24),
              Text(
                'مرحباً بك في يمن سيلو',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'التطبيق يعمل بنجاح',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
