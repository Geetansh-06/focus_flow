
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';
import '../../models/focus_session_model.dart';
import '../../services/notification_service.dart';
import 'focus_history_screen.dart';
import 'focus_settings_screen.dart';

class FocusScreen extends StatefulWidget {
  final VoidCallback? onSessionCompleted;

  const FocusScreen({
    super.key,
    this.onSessionCompleted,
  });

  @override
  FocusScreenState createState() => FocusScreenState();
}

class FocusScreenState extends State<FocusScreen> {
  Timer? _timer;

  String selectedMode = 'Focus';

  int focusDuration = 25;
  int shortBreakDuration = 5;
  int longBreakDuration = 15;

  int remainingSeconds = 25 * 60;
  int totalSeconds = 25 * 60;

  bool isRunning = false;
  bool isLoadingSettings = true;
  bool isSavingSession = false;

  @override
  void initState() {
    super.initState();
    _loadTimerSettings();
  }

  Future<void> _loadTimerSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      focusDuration = prefs.getInt('focus_duration_minutes') ?? 25;
      shortBreakDuration = prefs.getInt('short_break_minutes') ?? 5;
      longBreakDuration = prefs.getInt('long_break_minutes') ?? 15;

      totalSeconds = focusDuration * 60;
      remainingSeconds = totalSeconds;

      isLoadingSettings = false;
    });
  }

  Future<void> _openSettings() async {
    if (isRunning) {
      _pauseTimer();
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const FocusSettingsScreen(),
      ),
    );

    if (result == true) {
      await _loadTimerSettings();
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FocusHistoryScreen(),
      ),
    );
  }

  void _startTimer() {
    if (isLoadingSettings || remainingSeconds <= 0) return;

    if (isRunning) return;

    setState(() {
      isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (remainingSeconds > 1) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();

        setState(() {
          remainingSeconds = 0;
          isRunning = false;
        });

        _onTimerCompleted();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();

    if (!mounted) return;

    setState(() {
      isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();

    if (!mounted) return;

    setState(() {
      isRunning = false;
      remainingSeconds = totalSeconds;
    });
  }

  void _changeMode(String mode) {
    _timer?.cancel();

    int duration;

    switch (mode) {
      case 'Short Break':
        duration = shortBreakDuration;
        break;
      case 'Long Break':
        duration = longBreakDuration;
        break;
      default:
        duration = focusDuration;
    }

    setState(() {
      selectedMode = mode;
      isRunning = false;
      totalSeconds = duration * 60;
      remainingSeconds = totalSeconds;
    });
  }

  Future<void> _onTimerCompleted() async {
    if (selectedMode == 'Focus') {
      await _saveFocusSession();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedMode == 'Focus'
              ? 'Focus session completed! Great work.'
              : '$selectedMode completed!',
        ),
        backgroundColor: AppColors.forestGreen,
      ),
    );
  }

  Future<void> _saveFocusSession() async {
    if (isSavingSession) return;

    isSavingSession = true;

    try {
      await DatabaseHelper.instance.insertFocusSession(
        FocusSessionModel(
          durationSeconds: totalSeconds,
        ),
      );


      await NotificationService.instance.showFocusNotification(
        id: 300001,
        title: 'Focus Session Completed!',
        body: 'Great job! You completed your focus session. 🎯',
      );


      widget.onSessionCompleted?.call();
    } catch (e) {
      debugPrint('Unable to save focus session: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save focus session.'),
          ),
        );
      }
    } finally {
      isSavingSession = false;
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remaining.toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (totalSeconds <= 0) return 0;

    return 1 - (remainingSeconds / totalSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingSettings) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.oliveGreen,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              _buildModeSelector(),
              const SizedBox(height: 30),
              _buildTimer(),
              const SizedBox(height: 28),
              _buildControls(),
              const SizedBox(height: 25),
              _buildTipCard(),
              const SizedBox(height: 20),
              _buildQuickActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Focus Time',
                style: TextStyle(
                  color: AppColors.forestGreen,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Stay present. Make progress.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        _buildHeaderButton(
          icon: Icons.history_rounded,
          onTap: _openHistory,
        ),
        const SizedBox(width: 10),
        _buildHeaderButton(
          icon: Icons.settings_rounded,
          onTap: _openSettings,
        ),
      ],
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.softGreen,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 45,
          width: 45,
          child: Icon(
            icon,
            color: AppColors.forestGreen,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    final modes = ['Focus', 'Short Break', 'Long Break'];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: modes.map((mode) {
          final isSelected = selectedMode == mode;

          return Expanded(
            child: GestureDetector(
              onTap: () => _changeMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.forestGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  mode,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppColors.forestGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 30,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            selectedMode == 'Focus'
                ? 'TIME TO CONCENTRATE'
                : 'TIME TO RECHARGE',
            style: const TextStyle(
              color: AppColors.oliveGreen,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: 235,
            width: 235,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 10,
                    backgroundColor: AppColors.softGreen,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.oliveGreen,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTime(remainingSeconds),
                      style: const TextStyle(
                        color: AppColors.forestGreen,
                        fontSize: 47,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRunning ? 'Stay focused...' : 'Ready when you are',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Text(
            selectedMode == 'Focus'
                ? 'One task at a time. You can do this.'
                : 'Take a breath and relax.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _resetTimer,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.forestGreen,
              side: const BorderSide(color: AppColors.oliveGreen),
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: isRunning ? _pauseTimer : _startTimer,
            icon: Icon(
              isRunning
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
            label: Text(isRunning ? 'Pause' : 'Start Focus'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 17),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.oliveGreen,
            size: 25,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Focus Tip',
                  style: TextStyle(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Keep your phone away and work on just one task '
                      'until the timer ends.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickAction(
            icon: Icons.history_rounded,
            title: 'Focus History',
            onTap: _openHistory,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickAction(
            icon: Icons.tune_rounded,
            title: 'Timer Settings',
            onTap: _openSettings,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: AppColors.oliveGreen,
                size: 23,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.forestGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
