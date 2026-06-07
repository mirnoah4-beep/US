import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F4),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo/us_wordmark.png',
              width: 100,
              color: const Color(0xFF8B2E42),
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Color(0xFF8B2E42),
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
