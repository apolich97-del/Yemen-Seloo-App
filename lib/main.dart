import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // هذا السطر ضروري جداً قبل أي عملية تهيئة
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyA2aX5gDos7IBU3lkFM_i2nIpuAzMIsZgE",
      appId: "1:580529134357:android:47521410ef2d77eba3671c",
      messagingSenderId: "580529134357",
      projectId: "yemen-seloo-app",
      storageBucket: "yemen-seloo-app.firebasestorage.app",
    ),
  );
  
  runApp(const MyApp());
}
