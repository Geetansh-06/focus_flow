
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';

class FocusSettingsScreen extends StatefulWidget {
  const FocusSettingsScreen({super.key});

  @override
  State<FocusSettingsScreen> createState() =>
      _FocusSettingsScreenState();
}

class _FocusSettingsScreenState extends State<FocusSettingsScreen> {
  int dailyGoal = 120;
  int focusDuration = 25;
  int shortBreak = 5;
  int longBreak = 15;
  int longBreakInterval = 4;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      dailyGoal = prefs.getInt('daily_focus_goal_minutes') ?? 120;
      focusDuration = prefs.getInt('focus_duration_minutes') ?? 25;
      shortBreak = prefs.getInt('short_break_minutes') ?? 5;
      longBreak = prefs.getInt('long_break_minutes') ?? 15;
      longBreakInterval = prefs.getInt('long_break_interval') ?? 4;
      isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('daily_focus_goal_minutes', dailyGoal);
    await prefs.setInt('focus_duration_minutes', focusDuration);
    await prefs.setInt('short_break_minutes', shortBreak);
    await prefs.setInt('long_break_minutes', longBreak);
    await prefs.setInt('long_break_interval', longBreakInterval);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Focus settings saved successfully!'),
        backgroundColor: AppColors.forestGreen,
      ),
    );

    Navigator.pop(context, true);
  }

  Widget _buildDropdown({
    required String title,
    required String subtitle,
    required IconData icon,
    required int value,
    required List<int> options,
    required String suffix,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.forestGreen),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: value,
            underline: const SizedBox(),
            borderRadius: BorderRadius.circular(12),
            dropdownColor: AppColors.card,
            style: const TextStyle(
              color: AppColors.forestGreen,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            items: options.map((option) {
              return DropdownMenuItem<int>(
                value: option,
                child: Text('$option $suffix'),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.forestGreen,
        elevation: 0,
        title: const Text(
          'Focus Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customize Your Focus',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: AppColors.forestGreen,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Set your daily target and timer preferences.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'DAILY TARGET',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: AppColors.oliveGreen,
              ),
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              title: 'Daily Focus Goal',
              subtitle: 'Your target focused time per day',
              icon: Icons.flag_rounded,
              value: dailyGoal,
              options: List.generate(16, (i) => (i + 1) * 30),
              suffix: 'min',
              onChanged: (value) {
                if (value != null) {
                  setState(() => dailyGoal = value);
                }
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'POMODORO TIMER',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: AppColors.oliveGreen,
              ),
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              title: 'Focus Duration',
              subtitle: 'Time for one focus session',
              icon: Icons.center_focus_strong_rounded,
              value: focusDuration,
              options: List.generate(16, (i) => (i + 1) * 5),
              suffix: 'min',
              onChanged: (value) {
                if (value != null) {
                  setState(() => focusDuration = value);
                }
              },
            ),
            _buildDropdown(
              title: 'Short Break',
              subtitle: 'Quick rest between sessions',
              icon: Icons.coffee_rounded,
              value: shortBreak,
              options: List.generate(15, (i) => i + 1),
              suffix: 'min',
              onChanged: (value) {
                if (value != null) {
                  setState(() => shortBreak = value);
                }
              },
            ),
            _buildDropdown(
              title: 'Long Break',
              subtitle: 'Longer rest after multiple sessions',
              icon: Icons.weekend_rounded,
              value: longBreak,
              options: List.generate(12, (i) => (i + 1) * 5),
              suffix: 'min',
              onChanged: (value) {
                if (value != null) {
                  setState(() => longBreak = value);
                }
              },
            ),
            _buildDropdown(
              title: 'Long Break Interval',
              subtitle: 'Focus sessions before a long break',
              icon: Icons.repeat_rounded,
              value: longBreakInterval,
              options: List.generate(7, (i) => i + 2),
              suffix: 'sessions',
              onChanged: (value) {
                if (value != null) {
                  setState(() => longBreakInterval = value);
                }
              },
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
