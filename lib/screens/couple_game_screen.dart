import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/language_provider.dart';

class CoupleGameScreen extends StatelessWidget {
  const CoupleGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF2C2420)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(s.coupleGameTitle, style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: const Center(
        child: Text('Coming soon', style: TextStyle(fontSize: 18, color: Color(0xFFB4B2A9))),
      ),
    );
  }
}
