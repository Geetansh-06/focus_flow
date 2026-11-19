
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../onboarding/onboarding_screen.dart';
import '../navigation/main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();

    final completed =
        prefs.getBool('onboarding_completed') ?? false;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => completed
            ? const MainNavigationScreen()
            : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.forestGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.track_changes_rounded,
                size: 48,
                color: AppColors.oliveGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'FocusFlow',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: AppColors.textLight,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Make every moment productive',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.sageGreen,
              ),
            ),
            const SizedBox(height: 35),
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.softLime,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
