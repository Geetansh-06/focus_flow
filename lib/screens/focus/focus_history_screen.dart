
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';
import '../../models/focus_session_model.dart';

class FocusHistoryScreen extends StatefulWidget {
  const FocusHistoryScreen({super.key});

  @override
  State<FocusHistoryScreen> createState() =>
      _FocusHistoryScreenState();
}

class _FocusHistoryScreenState extends State<FocusHistoryScreen> {
  List<FocusSessionModel> sessions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final data =
      await DatabaseHelper.instance.getFocusSessions();

      if (!mounted) return;

      setState(() {
        sessions = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load history: $e'),
        ),
      );
    }
  }

  int get totalFocusSeconds {
    return sessions.fold(
      0,
          (total, session) => total + session.durationSeconds,
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes} min';
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Focus History',
          style: TextStyle(
            color: AppColors.forestGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: AppColors.forestGreen,
        ),
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: AppColors.oliveGreen,
        ),
      )
          : RefreshIndicator(
        color: AppColors.oliveGreen,
        onRefresh: _loadSessions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 28),
              const Text(
                'Completed Sessions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(height: 15),
              if (sessions.isEmpty)
                _buildEmptyState()
              else
                ...sessions.map(_buildSessionCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.forestGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Focus Time',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _formatDuration(totalFocusSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.timer_rounded,
                color: AppColors.softLime,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${sessions.length} sessions completed',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(FocusSessionModel session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.forestGreen,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Focus Session',
                  style: TextStyle(
                    color: AppColors.forestGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_formatDate(session.completedAt)} • '
                      '${_formatTime(session.completedAt)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatDuration(session.durationSeconds),
            style: const TextStyle(
              color: AppColors.oliveGreen,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 45,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: 48,
            color: AppColors.sageGreen,
          ),
          SizedBox(height: 15),
          Text(
            'No Focus Sessions Yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.forestGreen,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Complete a focus session to see your history here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
