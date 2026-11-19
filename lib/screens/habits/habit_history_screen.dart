
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';
import '../../models/habit_model.dart';

class HabitHistoryScreen extends StatefulWidget {
  final HabitModel habit;

  const HabitHistoryScreen({
    super.key,
    required this.habit,
  });

  @override
  State<HabitHistoryScreen> createState() =>
      _HabitHistoryScreenState();
}

class _HabitHistoryScreenState extends State<HabitHistoryScreen> {
  List<String> completionDates = [];

  bool isLoading = true;

  DateTime selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // LOAD HABIT HISTORY

  Future<void> _loadHistory() async {
    if (widget.habit.id == null) return;

    final dates = await DatabaseHelper.instance
        .getHabitCompletionDates(widget.habit.id!);

    if (!mounted) return;

    setState(() {
      completionDates = dates;
      isLoading = false;
    });
  }

  // FORMAT DATE

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // CHECK COMPLETION

  bool _isCompleted(DateTime date) {
    return completionDates.contains(_formatDate(date));
  }

  // MONTH NAME

  String get monthName {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[selectedMonth.month - 1]} ${selectedMonth.year}';
  }

  // MONTH DAYS

  int get daysInMonth {
    return DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
    ).day;
  }

  // MONTH COMPLETION COUNT

  int get monthlyCompletedCount {
    return completionDates.where((date) {
      final parsed = DateTime.parse(date);

      return parsed.year == selectedMonth.year &&
          parsed.month == selectedMonth.month;
    }).length;
  }

  // DAYS TO COUNT FOR COMPLETION PERCENTAGE

  int get daysConsidered {
    final now = DateTime.now();

    if (selectedMonth.year == now.year &&
        selectedMonth.month == now.month) {
      return now.day;
    }

    if (selectedMonth.isAfter(DateTime(now.year, now.month))) {
      return 0;
    }

    return daysInMonth;
  }

  // COMPLETION PERCENTAGE

  double get monthlyPercentage {
    if (daysConsidered == 0) return 0;

    return (monthlyCompletedCount / daysConsidered)
        .clamp(0.0, 1.0);
  }

  // TOTAL COMPLETED DAYS

  int get totalCompletedDays => completionDates.length;

  // CURRENT STREAK

  int get currentStreak {
    if (completionDates.isEmpty) return 0;

    final dates = completionDates
        .map((date) => DateTime.parse(date))
        .toSet()
        .toList()
      ..sort((a, b) => a.compareTo(b));

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterday = todayDate.subtract(
      const Duration(days: 1),
    );

    DateTime expectedDate = dates.last;

    if (expectedDate != todayDate &&
        expectedDate != yesterday) {
      return 0;
    }

    int streak = 0;

    for (int i = dates.length - 1; i >= 0; i--) {
      if (dates[i] == expectedDate) {
        streak++;
        expectedDate = expectedDate.subtract(
          const Duration(days: 1),
        );
      } else if (dates[i].isBefore(expectedDate)) {
        break;
      }
    }

    return streak;
  }

  // BEST STREAK

  int get bestStreak {
    if (completionDates.isEmpty) return 0;

    final dates = completionDates
        .map((date) => DateTime.parse(date))
        .toSet()
        .toList()
      ..sort((a, b) => a.compareTo(b));

    int best = 1;
    int running = 1;

    for (int i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays == 1) {
        running++;
      } else {
        running = 1;
      }

      if (running > best) {
        best = running;
      }
    }

    return best;
  }

  // CHANGE MONTH

  void _changeMonth(int difference) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + difference,
      );
    });
  }

  // CALENDAR

  Widget _buildCalendar() {
    const weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    final firstDay = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );

    final startingOffset = firstDay.weekday - 1;

    final totalCells = ((startingOffset + daysInMonth + 6) ~/ 7) * 7;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekdays.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 10,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - startingOffset + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox();
              }

              final date = DateTime(
                selectedMonth.year,
                selectedMonth.month,
                dayNumber,
              );

              final completed = _isCompleted(date);
              final isToday = date == todayDate;
              final isFuture = date.isAfter(todayDate);

              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: completed
                      ? AppColors.oliveGreen
                      : AppColors.softGreen,
                  shape: BoxShape.circle,
                  border: isToday
                      ? Border.all(
                    color: AppColors.forestGreen,
                    width: 1.5,
                  )
                      : null,
                ),
                child: completed
                    ? const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 17,
                )
                    : Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isFuture
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.oliveGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Completed',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 18),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.softGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Not completed',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // STAT CARD

  Widget _buildStatCard(
      String title,
      String value,
      IconData icon,
      Color iconColor,
      ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 23,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // MAIN SCREEN

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Habit History',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadHistory,
        color: AppColors.oliveGreen,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.habit.name,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              widget.habit.category,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.oliveGreen,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 22),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _buildStatCard(
                  'Completed Days',
                  '$totalCompletedDays',
                  Icons.check_circle_rounded,
                  AppColors.oliveGreen,
                ),
                _buildStatCard(
                  'Completion Rate',
                  '${(monthlyPercentage * 100).round()}%',
                  Icons.pie_chart_rounded,
                  AppColors.forestGreen,
                ),
                _buildStatCard(
                  'Current Streak',
                  '$currentStreak days',
                  Icons.local_fire_department_rounded,
                  const Color(0xFFD98A42),
                ),
                _buildStatCard(
                  'Best Streak',
                  '$bestStreak days',
                  Icons.emoji_events_rounded,
                  const Color(0xFFB99A43),
                ),
              ],
            ),

            const SizedBox(height: 26),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monthly Calendar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(
                        Icons.chevron_left,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    Text(
                      monthName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final now = DateTime.now();
                        final nextMonth = DateTime(
                          selectedMonth.year,
                          selectedMonth.month + 1,
                        );

                        if (!nextMonth.isAfter(
                          DateTime(now.year, now.month),
                        )) {
                          _changeMonth(1);
                        }
                      },
                      icon: const Icon(
                        Icons.chevron_right,
                        color: AppColors.forestGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            _buildCalendar(),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Progress',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: monthlyPercentage,
                      minHeight: 9,
                      backgroundColor: Colors.white,
                      valueColor:
                      const AlwaysStoppedAnimation(
                        AppColors.oliveGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$monthlyCompletedCount of $daysConsidered days completed',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
