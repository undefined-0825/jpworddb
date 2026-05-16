import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'purchase_service.dart';
import 'title_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PurchaseService.instance.init();
  await MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'コトノハ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D4C41)),
        useMaterial3: true,
      ),
      home: const TitleScreen(),
    );
  }
}
