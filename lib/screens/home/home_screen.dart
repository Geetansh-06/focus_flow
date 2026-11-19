
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../calendar/calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onAddTask;
  final VoidCallback onStartFocus;
  final VoidCallback onTrackHabit;
  final VoidCallback onTaskChanged;

  const HomeScreen({
    super.key,
    required this.onAddTask,
    required this.onStartFocus,
    required this.onTrackHabit,
    required this.onTaskChanged,
  });

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<TaskModel> tasks = [];
  List<HabitModel> habits = [];

  Map<int, Set<String>> habitCompletions = {};

  bool isLoading = true;
  bool isFocusLoading = true;
  bool isHabitLoading = true;

  int totalFocusSeconds = 0;
  int weeklyFocusSeconds = 0;
  int weeklyHabitCompletions = 0;
  int todayCompletedHabits = 0;

  int todayFocusSeconds = 0;
  int dailyFocusGoalMinutes = 120;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadFocusTime();
    _loadHabits();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  DateTime get _weekStart {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 7));

  Future<void> _loadTasks() async {
    try {
      final loadedTasks = await DatabaseHelper.instance.getTasks();

      if (!mounted) return;

      setState(() {
        tasks = loadedTasks;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading home tasks: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadFocusTime() async {
    try {
      final results = await Future.wait([
        DatabaseHelper.instance.getFocusSessions(),
        SharedPreferences.getInstance(),
      ]);

      final sessions = results[0] as List;
      final prefs = results[1] as SharedPreferences;

      final totalSeconds = sessions.fold<int>(
        0,
            (total, session) =>
            (total + session.durationSeconds).toInt(),
      );

      final weekSeconds = sessions.where((session) {
        final date = session.completedAt;

        return !date.isBefore(_weekStart) &&
            date.isBefore(_weekEnd);
      }).fold<int>(
        0,
            (total, session) =>
            (total + session.durationSeconds).toInt(),
      );

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrow = todayStart.add(const Duration(days: 1));

      final todaySeconds = sessions.where((session) {
        final date = session.completedAt;

        return !date.isBefore(todayStart) &&
            date.isBefore(tomorrow);
      }).fold<int>(
        0,
            (total, session) =>
            (total + session.durationSeconds).toInt(),
      );

      final goal =
          prefs.getInt('daily_focus_goal_minutes') ?? 120;

      if (!mounted) return;

      setState(() {
        totalFocusSeconds = totalSeconds;
        weeklyFocusSeconds = weekSeconds;
        todayFocusSeconds = todaySeconds;
        dailyFocusGoalMinutes = goal;
        isFocusLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading focus time: $e');

      if (!mounted) return;

      setState(() {
        isFocusLoading = false;
      });
    }
  }

  Future<void> _loadHabits() async {
    try {
      final loadedHabits =
      await DatabaseHelper.instance.getHabits(activeOnly: true);

      final Map<int, Set<String>> completionData = {};

      int todayCount = 0;
      int weeklyCount = 0;

      final today = _formatDate(DateTime.now());
      final weekStart = _formatDate(_weekStart);
      final weekEnd = _formatDate(_weekEnd);

      for (final habit in loadedHabits) {
        if (habit.id == null) continue;

        final dates = await DatabaseHelper.instance
            .getHabitCompletionDates(habit.id!);

        final dateSet = dates.toSet();
        completionData[habit.id!] = dateSet;

        if (dateSet.contains(today)) {
          todayCount++;
        }

        weeklyCount += dateSet.where((date) {
          return date.compareTo(weekStart) >= 0 &&
              date.compareTo(weekEnd) < 0;
        }).length;
      }

      if (!mounted) return;

      setState(() {
        habits = loadedHabits;
        habitCompletions = completionData;
        todayCompletedHabits = todayCount;
        weeklyHabitCompletions = weeklyCount;
        isHabitLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading home habits: $e');

      if (!mounted) return;

      setState(() {
        isHabitLoading = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) return '${hours}h ${minutes}m';

    return '${minutes}m';
  }

  String get formattedFocusTime =>
      _formatDuration(totalFocusSeconds);

  String get formattedWeeklyFocusTime =>
      _formatDuration(weeklyFocusSeconds);

  Future<void> refreshTasks() async {
    await Future.wait([
      _loadTasks(),
      _loadFocusTime(),
      _loadHabits(),
    ]);
  }

  Future<void> _toggleHomeTask(TaskModel task) async {
    if (task.id == null) return;

    final updatedTask = TaskModel(
      id: task.id,
      title: task.title,
      description: task.description,
      category: task.category,
      priority: task.priority,
      completed: !task.completed,
      dueDate: task.dueDate,
      reminderDateTime: task.reminderDateTime,
      createdAt: task.createdAt,
    );

    try {
      await DatabaseHelper.instance.updateTask(updatedTask);

      if (!mounted) return;

      setState(() {
        final index = tasks.indexWhere(
              (item) => item.id == task.id,
        );

        if (index != -1) {
          tasks[index] = updatedTask;
        }
      });

      widget.onTaskChanged();
    } catch (e) {
      debugPrint('Error updating home task: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update task. Please try again.',
          ),
        ),
      );
    }
  }

  List<TaskModel> get todayTasks {
    final now = DateTime.now();

    return tasks.where((task) {
      if (task.dueDate == null) return false;

      return task.dueDate!.year == now.year &&
          task.dueDate!.month == now.month &&
          task.dueDate!.day == now.day;
    }).toList();
  }

  int get completedTasks =>
      tasks.where((task) => task.completed).length;

  int get totalTasks => tasks.length;

  int get pendingTasks => totalTasks - completedTasks;

  double get progress {
    if (totalTasks == 0) return 0;
    return completedTasks / totalTasks;
  }

  double get habitProgress {
    if (habits.isEmpty) return 0;
    return todayCompletedHabits / habits.length;
  }

  String get greeting {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon 👋';

    return 'Good Evening 👋';
  }

  void _openCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CalendarScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.oliveGreen,
          onRefresh: refreshTasks,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 25),
                _buildProgressCard(),
                const SizedBox(height: 16),
                _buildDailyFocusGoalCard(),
                const SizedBox(height: 16),
                _buildHabitProgressCard(),
                const SizedBox(height: 27),
                _buildSectionTitle('Your Overview'),
                const SizedBox(height: 13),
                _buildStats(),
                const SizedBox(height: 27),
                _buildSectionTitle('Quick Actions'),
                const SizedBox(height: 13),
                _buildQuickActions(),
                const SizedBox(height: 27),
                _buildWeeklyOverview(),
                const SizedBox(height: 17),
                _buildCalendarShortcut(),
                const SizedBox(height: 27),
                _buildSectionTitle("Today's Tasks"),
                const SizedBox(height: 13),
                _buildTodayTasks(),
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
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];

    final date = '${now.day} ${months[now.month - 1]} ${now.year}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: AppColors.oliveGreen,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: AppColors.forestGreen,
            size: 29,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.forestGreen,
            Color(0xFF354F3E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestGreen.withOpacity(0.13),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Overall Task Progress',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ALL TASKS',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completedTasks of $totalTasks',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      totalTasks == 0
                          ? 'Add your first task!'
                          : 'Tasks completed',
                      style: const TextStyle(
                        color: AppColors.sageGreen,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.softLime,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 11,
              backgroundColor: const Color(0xFF52675B),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.softLime,
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            totalTasks == 0
                ? 'Start small. Build your momentum.'
                : pendingTasks == 0
                ? 'Excellent! You completed all your tasks.'
                : '$pendingTasks tasks remaining. Keep going!',
            style: const TextStyle(
              color: AppColors.sageGreen,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyFocusGoalCard() {
    final goalSeconds = dailyFocusGoalMinutes * 60;

    final focusProgress = goalSeconds <= 0
        ? 0.0
        : (todayFocusSeconds / goalSeconds)
        .clamp(0.0, 1.0)
        .toDouble();

    final remainingSeconds =
    (goalSeconds - todayFocusSeconds)
        .clamp(0, goalSeconds)
        .toInt();

    final isGoalCompleted =
        goalSeconds > 0 && todayFocusSeconds >= goalSeconds;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconContainer(
                Icons.track_changes_rounded,
                AppColors.softGreen,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Focus Goal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Make today count!',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isFocusLoading
                    ? '...'
                    : '${(focusProgress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.oliveGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFocusLoading
                          ? 'Loading...'
                          : _formatDuration(todayFocusSeconds),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Today's focused time",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Goal: ${dailyFocusGoalMinutes}m',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.oliveGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: isFocusLoading ? null : focusProgress,
              minHeight: 10,
              backgroundColor: AppColors.softGreen,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.oliveGreen,
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            isFocusLoading
                ? 'Calculating your progress...'
                : isGoalCompleted
                ? 'Amazing! You completed your daily focus goal!'
                : '${_formatDuration(remainingSeconds)} remaining to reach your goal.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isGoalCompleted
                  ? AppColors.success
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitProgressCard() {
    final remaining = habits.length - todayCompletedHabits;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconContainer(
                Icons.local_fire_department_rounded,
                const Color(0xFFF1EEDC),
                iconColor: AppColors.oliveGreen,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Today's Habit Progress",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
              Text(
                isHabitLoading
                    ? '...'
                    : '${(habitProgress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.oliveGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: isHabitLoading ? null : habitProgress,
              minHeight: 10,
              backgroundColor: AppColors.softGreen,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.oliveGreen,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  isHabitLoading
                      ? 'Loading habits...'
                      : '$todayCompletedHabits of ${habits.length} habits completed',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (!isHabitLoading)
                Text(
                  habits.isEmpty
                      ? 'Add a habit'
                      : remaining == 0
                      ? 'All done!'
                      : '$remaining remaining',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.oliveGreen,
                  ),
                ),
            ],
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
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.forestGreen,
      ),
    );
  }

  Widget _buildStats() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 350;

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle_outline_rounded,
                title: 'Tasks Done',
                value: completedTasks.toString(),
                subtitle: 'All tasks',
                color: AppColors.oliveGreen,
                compact: compact,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                icon: Icons.timer_outlined,
                title: 'Focus Time',
                value: isFocusLoading ? '...' : formattedFocusTime,
                subtitle: 'All Time',
                color: AppColors.forestGreen,
                compact: compact,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                icon: Icons.pending_actions_rounded,
                title: 'Pending',
                value: pendingTasks.toString(),
                subtitle: 'Tasks left',
                color: AppColors.oliveGreen,
                compact: compact,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required bool compact,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 137),
      padding: EdgeInsets.symmetric(
        vertical: compact ? 13 : 16,
        horizontal: compact ? 8 : 11,
      ),
      decoration: _cardDecoration(radius: 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 13),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.forestGreen,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
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
          child: _buildActionCard(
            icon: Icons.add_task_rounded,
            title: 'Add Task',
            color: AppColors.softGreen,
            onTap: widget.onAddTask,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionCard(
            icon: Icons.play_circle_outline_rounded,
            title: 'Start Focus',
            color: const Color(0xFFEDEFD9),
            onTap: widget.onStartFocus,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionCard(
            icon: Icons.track_changes_rounded,
            title: 'Track Habit',
            color: const Color(0xFFE8EDE3),
            onTap: widget.onTrackHabit,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.symmetric(
            vertical: 17,
            horizontal: 5,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 27,
                color: AppColors.forestGreen,
              ),
              const SizedBox(height: 11),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forestGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyOverview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Weekly Overview',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'This Week',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.oliveGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _buildWeeklyItem(
                  icon: Icons.timer_rounded,
                  title: 'Focus Time',
                  value: isFocusLoading
                      ? '...'
                      : formattedWeeklyFocusTime,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: _buildWeeklyItem(
                  icon: Icons.check_circle_rounded,
                  title: 'Habit Check-ins',
                  value: isHabitLoading
                      ? '...'
                      : weeklyHabitCompletions.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'Small consistent steps create big progress.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.oliveGreen,
            size: 22,
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.forestGreen,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarShortcut() {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: _openCalendar,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _iconContainer(
                Icons.calendar_month_rounded,
                AppColors.softGreen,
                size: 49,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open Calendar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'View your tasks, habits and focus sessions by date.',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.oliveGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayTasks() {
    final items = todayTasks;

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(25),
          child: CircularProgressIndicator(
            color: AppColors.oliveGreen,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: items.isEmpty
          ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 39,
              color: AppColors.sageGreen,
            ),
            SizedBox(height: 12),
            Text(
              'No tasks due today',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.forestGreen,
              ),
            ),
            SizedBox(height: 6),
            Text(
              "Tasks with today's due date will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      )
          : Column(
        children: List.generate(items.length, (index) {
          final task = items[index];

          return Column(
            children: [
              _buildTaskItem(
                title: task.title,
                isCompleted: task.completed,
                category: task.category,
                onTap: () => _toggleHomeTask(task),
              ),
              if (index != items.length - 1)
                const Divider(
                  height: 22,
                  color: AppColors.border,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTaskItem({
    required String title,
    required bool isCompleted,
    required String category,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Material(
          color: isCompleted
              ? AppColors.softGreen
              : AppColors.background,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              height: 42,
              width: 42,
              child: Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isCompleted
                    ? AppColors.success
                    : AppColors.textSecondary,
                size: 23,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isCompleted
                      ? AppColors.textSecondary
                      : AppColors.forestGreen,
                  decoration: isCompleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration({double radius = 22}) {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
    );
  }

  Widget _iconContainer(
      IconData icon,
      Color background, {
        Color iconColor = AppColors.forestGreen,
        double size = 44,
      }) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: 24,
      ),
    );
  }
}

