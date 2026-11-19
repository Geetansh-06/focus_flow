import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';
import '../../models/focus_session_model.dart';
import '../../models/habit_model.dart';
import '../../models/task_model.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool isLoading = true;

  List<TaskModel> tasks = [];
  List<FocusSessionModel> focusSessions = [];
  List<HabitModel> habits = [];

  final List<DateTime> weekDates = [];

  final List<int> dailyDueTasks = List.filled(7, 0);
  final List<int> dailyCompletedTasks = List.filled(7, 0);
  final List<int> dailyFocusMinutes = List.filled(7, 0);
  final List<int> dailyCompletedHabits = List.filled(7, 0);

  int totalHabitCompletions = 0;

  @override
  void initState() {
    super.initState();
    _prepareWeek();
    _loadAnalytics();
  }

  void _prepareWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Monday se Sunday tak current week.
    final monday = today.subtract(
      Duration(days: today.weekday - 1),
    );

    weekDates.clear();

    for (int i = 0; i < 7; i++) {
      weekDates.add(monday.add(Duration(days: i)));
    }
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  int _weekIndex(DateTime date) {
    final key = _dateKey(date);

    return weekDates.indexWhere(
          (weekDate) => _dateKey(weekDate) == key,
    );
  }

  Future<void> _loadAnalytics() async {
    try {
      final db = DatabaseHelper.instance;

      final loadedTasks = await db.getTasks();
      final loadedSessions = await db.getFocusSessions();
      final loadedHabits = await db.getHabits(activeOnly: true);

      final habitDates = <int, List<String>>{};

      for (final habit in loadedHabits) {
        if (habit.id == null) continue;

        habitDates[habit.id!] =
        await db.getHabitCompletionDates(habit.id!);
      }

      if (!mounted) return;

      setState(() {
        tasks = loadedTasks;
        focusSessions = loadedSessions;
        habits = loadedHabits;

        _calculateWeeklyData(habitDates);

        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load analytics data.'),
        ),
      );
    }
  }

  void _calculateWeeklyData(
      Map<int, List<String>> habitDates,
      ) {
    for (int i = 0; i < 7; i++) {
      dailyDueTasks[i] = 0;
      dailyCompletedTasks[i] = 0;
      dailyFocusMinutes[i] = 0;
      dailyCompletedHabits[i] = 0;
    }

    totalHabitCompletions = 0;

    // Tasks: due date ke basis par weekly count.
    for (final task in tasks) {
      if (task.dueDate == null) continue;

      final index = _weekIndex(task.dueDate!);

      if (index == -1) continue;

      dailyDueTasks[index]++;

      if (task.completed) {
        dailyCompletedTasks[index]++;
      }
    }

    // Focus sessions: actual completion date ke basis par.
    for (final session in focusSessions) {
      final index = _weekIndex(session.completedAt);

      if (index == -1) continue;

      dailyFocusMinutes[index] +=
          (session.durationSeconds / 60).round();
    }

    // Habit completions: saved completion dates ke basis par.
    for (final dates in habitDates.values) {
      totalHabitCompletions += dates.length;

      for (final dateString in dates) {
        final date = DateTime.tryParse(dateString);

        if (date == null) continue;

        final index = _weekIndex(date);

        if (index != -1) {
          dailyCompletedHabits[index]++;
        }
      }
    }
  }

  int get completedTasks {
    return tasks.where((task) => task.completed).length;
  }

  int get pendingTasks {
    return tasks.length - completedTasks;
  }

  int get totalFocusSeconds {
    return focusSessions.fold<int>(
      0,
          (total, session) => total + session.durationSeconds,
    );
  }

  String get totalFocusTime {
    final hours = totalFocusSeconds ~/ 3600;
    final minutes = (totalFocusSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }

  int get weeklyFocusMinutes {
    return dailyFocusMinutes.fold<int>(
      0,
          (total, minutes) => total + minutes,
    );
  }

  String get weeklyFocusTime {
    final hours = weeklyFocusMinutes ~/ 60;
    final minutes = weeklyFocusMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }

  double get taskCompletionPercentage {
    if (tasks.isEmpty) return 0;
    return completedTasks / tasks.length * 100;
  }

  String _weekdayLabel(int index) {
    const days = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    return days[index];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: AppColors.oliveGreen,
          ),
        )
            : RefreshIndicator(
          color: AppColors.oliveGreen,
          onRefresh: _loadAnalytics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSummaryGrid(),
                const SizedBox(height: 28),
                _buildSectionTitle('Weekly Productivity'),
                const SizedBox(height: 14),
                _buildTaskChart(),
                const SizedBox(height: 18),
                _buildFocusChart(),
                const SizedBox(height: 18),
                _buildHabitChart(),
                const SizedBox(height: 24),
                _buildInsightCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Performance',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.forestGreen,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${months[now.month - 1]} ${now.year} • Weekly Analytics',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.task_alt_rounded,
                title: 'Tasks Done',
                value: completedTasks.toString(),
                subtitle: 'of ${tasks.length} total tasks',
                color: AppColors.oliveGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.timer_rounded,
                title: 'Focus Time',
                value: totalFocusTime,
                subtitle: 'All time',
                color: AppColors.forestGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.pending_actions_rounded,
                title: 'Pending Tasks',
                value: pendingTasks.toString(),
                subtitle: 'Tasks remaining',
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.local_fire_department_rounded,
                title: 'Habit Check-ins',
                value: totalHabitCompletions.toString(),
                subtitle: '${habits.length} active habits',
                color: AppColors.oliveGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 13),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: AppColors.forestGreen,
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required Widget chart,
    Widget? legend,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: chart,
          ),
          if (legend != null) ...[
            const SizedBox(height: 12),
            legend,
          ],
        ],
      ),
    );
  }

  Widget _buildTaskChart() {
    final maxValue = dailyDueTasks.fold<int>(
      0,
          (current, value) => value > current ? value : current,
    );

    final maxY = (maxValue + 1).clamp(4, 20).toDouble();

    final groups = List.generate(7, (index) {
      return BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: dailyDueTasks[index].toDouble(),
            color: AppColors.sageGreen,
            width: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: dailyCompletedTasks[index].toDouble(),
            color: AppColors.forestGreen,
            width: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    return _buildChartCard(
      title: 'Task Overview',
      subtitle: 'Tasks due and completed this week',
      chart: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.border,
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          titlesData: _buildChartTitles(),
          barTouchData: BarTouchData(enabled: true),
        ),
      ),
      legend: _buildLegend([
        _LegendItem('Due', AppColors.sageGreen),
        _LegendItem('Completed', AppColors.forestGreen),
      ]),
    );
  }

  Widget _buildFocusChart() {
    final maxValue = dailyFocusMinutes.fold<int>(
      0,
          (current, value) => value > current ? value : current,
    );

    final maxY = (maxValue + 15).clamp(60, 600).toDouble();

    final groups = List.generate(7, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: dailyFocusMinutes[index].toDouble(),
            color: AppColors.oliveGreen,
            width: 19,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    });

    return _buildChartCard(
      title: 'Focus Time',
      subtitle: 'Daily focus minutes this week',
      chart: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.border,
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          titlesData: _buildChartTitles(),
          barTouchData: BarTouchData(enabled: true),
        ),
      ),
      legend: _buildLegend([
        _LegendItem('Focus minutes', AppColors.oliveGreen),
      ]),
    );
  }

  Widget _buildHabitChart() {
    final maxValue = dailyCompletedHabits.fold<int>(
      0,
          (current, value) => value > current ? value : current,
    );

    final maxY = (maxValue + 1).clamp(4, 20).toDouble();

    final groups = List.generate(7, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: dailyCompletedHabits[index].toDouble(),
            color: AppColors.sageGreen,
            width: 19,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    });

    return _buildChartCard(
      title: 'Habit Consistency',
      subtitle: 'Completed habit check-ins each day',
      chart: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.border,
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          titlesData: _buildChartTitles(),
          barTouchData: BarTouchData(enabled: true),
        ),
      ),
      legend: _buildLegend([
        _LegendItem('Completed habits', AppColors.sageGreen),
      ]),
    );
  }

  FlTitlesData _buildChartTitles() {
    return FlTitlesData(
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      leftTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();

            if (index < 0 || index > 6) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _weekdayLabel(index),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend(List<_LegendItem> items) {
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 9,
              width: 9,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildInsightCard() {
    final weeklyTasks = dailyDueTasks.fold<int>(
      0,
          (total, value) => total + value,
    );

    final weeklyCompleted = dailyCompletedTasks.fold<int>(
      0,
          (total, value) => total + value,
    );

    final weeklyHabits = dailyCompletedHabits.fold<int>(
      0,
          (total, value) => total + value,
    );

    final percentage = weeklyTasks == 0
        ? 0
        : (weeklyCompleted / weeklyTasks * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: AppColors.forestGreen,
              ),
              SizedBox(width: 9),
              Text(
                'This Week at a Glance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forestGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildInsightRow(
            'Tasks completed',
            '$weeklyCompleted / $weeklyTasks',
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Task completion rate',
            '$percentage%',
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Focus time',
            weeklyFocusTime,
          ),
          const SizedBox(height: 10),
          _buildInsightRow(
            'Habit check-ins',
            weeklyHabits.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.forestGreen,
          ),
        ),
      ],
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;

  const _LegendItem(this.label, this.color);
}