
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';
import '../../models/task_model.dart';
import '../../models/habit_model.dart';
import '../../models/focus_session_model.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDate = DateTime.now();
  DateTime displayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  bool isLoading = true;

  List<TaskModel> tasks = [];
  List<HabitModel> habits = [];
  List<FocusSessionModel> focusSessions = [];

  Map<int, Set<String>> habitCompletionDates = {};

  @override
  void initState() {
    super.initState();
    _loadCalendarData();
  }

  String _dateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Future<void> _loadCalendarData() async {
    try {
      final db = DatabaseHelper.instance;

      final loadedTasks = await db.getTasks();
      final loadedHabits = await db.getHabits(activeOnly: true);
      final loadedSessions = await db.getFocusSessions();

      final completionMap = <int, Set<String>>{};

      for (final habit in loadedHabits) {
        if (habit.id == null) continue;

        final dates = await db.getHabitCompletionDates(habit.id!);
        completionMap[habit.id!] = dates.toSet();
      }

      if (!mounted) return;

      setState(() {
        tasks = loadedTasks;
        habits = loadedHabits;
        focusSessions = loadedSessions;
        habitCompletionDates = completionMap;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading calendar: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load calendar data.'),
        ),
      );
    }
  }

  Future<void> _refreshCalendar() async {
    setState(() {
      isLoading = true;
    });

    await _loadCalendarData();
  }

  void _changeMonth(int amount) {
    setState(() {
      displayedMonth = DateTime(
        displayedMonth.year,
        displayedMonth.month + amount,
      );
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      selectedDate = date;
      displayedMonth = DateTime(date.year, date.month);
    });
  }

  List<TaskModel> get selectedDateTasks {
    return tasks.where((task) {
      if (task.dueDate == null) return false;
      return _isSameDay(task.dueDate!, selectedDate);
    }).toList();
  }

  List<HabitModel> get selectedDateHabits {
    return habits.where((habit) {
      if (habit.id == null) return false;

      return habitCompletionDates[habit.id]?.contains(
        _dateKey(selectedDate),
      ) ??
          false;
    }).toList();
  }

  List<FocusSessionModel> get selectedDateSessions {
    return focusSessions.where((session) {
      return _isSameDay(session.completedAt, selectedDate);
    }).toList();
  }

  int get selectedDateFocusSeconds {
    return selectedDateSessions.fold<int>(
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

    return '${minutes}m';
  }

  bool _hasTask(DateTime date) {
    return tasks.any((task) {
      return task.dueDate != null &&
          _isSameDay(task.dueDate!, date);
    });
  }

  bool _hasHabitCompletion(DateTime date) {
    final key = _dateKey(date);

    return habitCompletionDates.values.any(
          (dates) => dates.contains(key),
    );
  }

  bool _hasFocusSession(DateTime date) {
    return focusSessions.any(
          (session) => _isSameDay(session.completedAt, date),
    );
  }

  List<DateTime> get calendarDays {
    final firstDay = DateTime(
      displayedMonth.year,
      displayedMonth.month,
      1,
    );

    final startOffset = firstDay.weekday - 1;
    final calendarStart = firstDay.subtract(
      Duration(days: startOffset),
    );

    return List.generate(
      42,
          (index) => calendarStart.add(Duration(days: index)),
    );
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
          onRefresh: _refreshCalendar,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 22),
                _buildCalendarCard(),
                const SizedBox(height: 20),
                _buildSelectedDateHeader(),
                const SizedBox(height: 14),
                _buildSelectedDateSummary(),
                const SizedBox(height: 20),
                _buildTaskSection(),
                const SizedBox(height: 18),
                _buildHabitSection(),
                const SizedBox(height: 18),
                _buildFocusSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Calendar',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.forestGreen,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Plan your days and review your progress.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCard() {
    final monthTitle = DateFormat(
      'MMMM yyyy',
    ).format(displayedMonth);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forestGreen,
                ),
              ),
              Row(
                children: [
                  _monthButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _changeMonth(-1),
                  ),
                  const SizedBox(width: 8),
                  _monthButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _changeMonth(1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ].map((day) {
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
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 7,
              crossAxisSpacing: 4,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final date = calendarDays[index];

              final isCurrentMonth =
                  date.month == displayedMonth.month;

              final isSelected = _isSameDay(
                date,
                selectedDate,
              );

              final isToday = _isSameDay(
                date,
                DateTime.now(),
              );

              return _buildCalendarDay(
                date: date,
                isCurrentMonth: isCurrentMonth,
                isSelected: isSelected,
                isToday: isToday,
              );
            },
          ),
          const SizedBox(height: 15),
          _buildCalendarLegend(),
        ],
      ),
    );
  }

  Widget _monthButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          color: AppColors.softGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 21,
          color: AppColors.forestGreen,
        ),
      ),
    );
  }

  Widget _buildCalendarDay({
    required DateTime date,
    required bool isCurrentMonth,
    required bool isSelected,
    required bool isToday,
  }) {
    final hasTask = _hasTask(date);
    final hasHabit = _hasHabitCompletion(date);
    final hasFocus = _hasFocusSession(date);

    return InkWell(
      onTap: () => _selectDate(date),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.forestGreen
              : isToday
              ? AppColors.softGreen
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.oliveGreen)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.day.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected || isToday
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: !isCurrentMonth
                    ? AppColors.textSecondary.withValues(alpha: 0.35)
                    : isSelected
                    ? Colors.white
                    : AppColors.forestGreen,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasTask)
                  _calendarDot(
                    isSelected ? AppColors.softLime : AppColors.oliveGreen,
                  ),
                if (hasHabit)
                  _calendarDot(
                    isSelected ? Colors.white : AppColors.success,
                  ),
                if (hasFocus)
                  _calendarDot(
                    isSelected ? AppColors.sageGreen : AppColors.forestGreen,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendarDot(Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      height: 4,
      width: 4,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCalendarLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _legendItem(AppColors.oliveGreen, 'Tasks'),
        _legendItem(AppColors.success, 'Habits'),
        _legendItem(AppColors.forestGreen, 'Focus'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 7,
          width: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDateHeader() {
    final dateText = DateFormat(
      'EEEE, dd MMMM yyyy',
    ).format(selectedDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Overview',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            _selectDate(DateTime.now());
          },
          child: const Text(
            'Today',
            style: TextStyle(
              color: AppColors.oliveGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDateSummary() {
    final completed = selectedDateTasks
        .where((task) => task.completed)
        .length;

    return Row(
      children: [
        Expanded(
          child: _summaryBox(
            icon: Icons.task_alt_rounded,
            value: selectedDateTasks.length.toString(),
            label: 'Tasks',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryBox(
            icon: Icons.check_circle_outline_rounded,
            value: completed.toString(),
            label: 'Done',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryBox(
            icon: Icons.timer_outlined,
            value: _formatDuration(selectedDateFocusSeconds),
            label: 'Focus',
          ),
        ),
      ],
    );
  }

  Widget _summaryBox({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 15,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.forestGreen,
            size: 21,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskSection() {
    final items = selectedDateTasks;

    return _buildSectionCard(
      title: 'Tasks',
      icon: Icons.checklist_rounded,
      trailing: '${items.length} tasks',
      child: items.isEmpty
          ? _emptyMessage('No tasks due on this date.')
          : Column(
        children: items.map((task) {
          return _buildTaskRow(task);
        }).toList(),
      ),
    );
  }

  Widget _buildTaskRow(TaskModel task) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(
            task.completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: task.completed
                ? AppColors.success
                : AppColors.textSecondary,
            size: 21,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${task.category} • ${task.priority}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            task.completed ? 'Done' : 'Pending',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: task.completed
                  ? AppColors.success
                  : AppColors.oliveGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitSection() {
    final items = selectedDateHabits;

    return _buildSectionCard(
      title: 'Completed Habits',
      icon: Icons.track_changes_rounded,
      trailing: '${items.length} completed',
      child: items.isEmpty
          ? _emptyMessage('No habits completed on this date.')
          : Column(
        children: items.map((habit) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 21,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    habit.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
                const Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFocusSection() {
    final items = selectedDateSessions;

    return _buildSectionCard(
      title: 'Focus Sessions',
      icon: Icons.timer_rounded,
      trailing: _formatDuration(selectedDateFocusSeconds),
      child: items.isEmpty
          ? _emptyMessage('No focus sessions on this date.')
          : Column(
        children: items.map((session) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: AppColors.oliveGreen,
                  size: 21,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    DateFormat(
                      'hh:mm a',
                    ).format(session.completedAt),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
                Text(
                  _formatDuration(session.durationSeconds),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.oliveGreen,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required String trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppColors.forestGreen,
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          child,
        ],
      ),
    );
  }

  Widget _emptyMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
