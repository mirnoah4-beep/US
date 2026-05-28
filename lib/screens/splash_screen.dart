import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F4),
      body: Center(
        child: Image.asset(
          'assets/logo/us_wordmark.png',
          width: 100,
          color: const Color(0xFFC1544A),
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );
  }
}
