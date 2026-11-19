import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';
import '../../models/habit_model.dart';
import '../../services/notification_service.dart';
import 'habit_history_screen.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<HabitModel> habits = [];

  Map<int, bool> completedHabits = {};
  Map<int, Map<String, int>> habitStreaks = {};
  Map<int, Set<String>> weeklyCompletions = {};

  bool isLoading = true;

  final List<String> categories = [
    'Health',
    'Learning',
    'Personal',
    'Fitness',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  // LOAD HABITS AND COMPLETION DATA

  Future<void> _loadHabits() async {
    final loadedHabits = await DatabaseHelper.instance.getHabits(
      activeOnly: true,
    );

    Map<int, bool> completionStatus = {};
    Map<int, Map<String, int>> streakData = {};
    Map<int, Set<String>> weeklyData = {};

    for (final habit in loadedHabits) {
      if (habit.id != null) {
        final habitId = habit.id!;

        completionStatus[habitId] = await DatabaseHelper.instance
            .isHabitCompleted(habitId, DateTime.now());

        final dates = await DatabaseHelper.instance.getHabitCompletionDates(
          habitId,
        );

        streakData[habitId] = _calculateStreaks(dates);
        weeklyData[habitId] = dates.toSet();
      }
    }

    if (!mounted) return;

    setState(() {
      habits = loadedHabits;
      completedHabits = completionStatus;
      habitStreaks = streakData;
      weeklyCompletions = weeklyData;
      isLoading = false;
    });
  }

  // FORMAT TIME AS HH:mm

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  // CONVERT STORED TIME TO TIME OF DAY

  TimeOfDay? _parseReminderTime(String? reminderTime) {
    if (reminderTime == null || reminderTime.isEmpty) {
      return null;
    }

    final parts = reminderTime.split(':');

    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  // DISPLAY STORED TIME

  String _displayReminderTime(String reminderTime) {
    final time = _parseReminderTime(reminderTime);

    if (time == null) return reminderTime;

    return time.format(context);
  }

  // SCHEDULE OR CANCEL HABIT NOTIFICATION

  Future<void> _syncHabitNotification(HabitModel habit) async {
    if (habit.id == null) return;

    // Separate ID range from task notifications.
    final notificationId = habit.id! + 200000;

    if (habit.reminderTime == null || habit.reminderTime!.isEmpty) {
      await NotificationService.instance.cancelNotification(notificationId);
      return;
    }

    final time = _parseReminderTime(habit.reminderTime);

    if (time == null) {
      await NotificationService.instance.cancelNotification(notificationId);
      return;
    }

    await NotificationService.instance.cancelNotification(notificationId);

    await NotificationService.instance.scheduleDailyNotification(
      id: notificationId,
      title: 'FocusFlow Habit Reminder',
      body: 'Time to work on your habit: ${habit.name}',
      hour: time.hour,
      minute: time.minute,
    );
  }

  // OPEN HABIT HISTORY

  Future<void> _openHabitHistory(HabitModel habit) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HabitHistoryScreen(habit: habit)),
    );

    if (!mounted) return;

    await _loadHabits();
  }

  // COMPLETED HABITS COUNT

  int get completedCount {
    return completedHabits.values.where((value) => value).length;
  }

  // DAILY PROGRESS

  double get progress {
    if (habits.isEmpty) return 0;
    return completedCount / habits.length;
  }

  // CALCULATE CURRENT AND BEST STREAK

  Map<String, int> _calculateStreaks(List<String> dates) {
    if (dates.isEmpty) {
      return {'current': 0, 'best': 0};
    }

    final completedDates =
        dates
            .map((date) {
              final parsed = DateTime.parse(date);
              return DateTime(parsed.year, parsed.month, parsed.day);
            })
            .toSet()
            .toList()
          ..sort((a, b) => a.compareTo(b));

    int bestStreak = 1;
    int runningStreak = 1;

    for (int i = 1; i < completedDates.length; i++) {
      final difference = completedDates[i]
          .difference(completedDates[i - 1])
          .inDays;

      if (difference == 1) {
        runningStreak++;
      } else {
        runningStreak = 1;
      }

      if (runningStreak > bestStreak) {
        bestStreak = runningStreak;
      }
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterday = todayDate.subtract(const Duration(days: 1));

    final lastCompletedDate = completedDates.last;

    int currentStreak = 0;

    if (lastCompletedDate == todayDate || lastCompletedDate == yesterday) {
      DateTime expectedDate = lastCompletedDate;

      for (int i = completedDates.length - 1; i >= 0; i--) {
        if (completedDates[i] == expectedDate) {
          currentStreak++;
          expectedDate = expectedDate.subtract(const Duration(days: 1));
        } else if (completedDates[i].isBefore(expectedDate)) {
          break;
        }
      }
    }

    return {'current': currentStreak, 'best': bestStreak};
  }

  // GET CURRENT WEEK DATES (MONDAY TO SUNDAY)

  List<DateTime> get currentWeekDates {
    final today = DateTime.now();

    final todayDate = DateTime(today.year, today.month, today.day);

    final monday = todayDate.subtract(Duration(days: todayDate.weekday - 1));

    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  // FORMAT DATE FOR DATABASE COMPARISON

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // CHECK WEEKLY COMPLETION

  bool _isCompletedOnDate(HabitModel habit, DateTime date) {
    if (habit.id == null) return false;

    return weeklyCompletions[habit.id]?.contains(_formatDate(date)) ?? false;
  }

  // COMPLETE OR UNCOMPLETE HABIT

  Future<void> _toggleHabit(HabitModel habit) async {
    if (habit.id == null) return;

    final isCompleted = completedHabits[habit.id] ?? false;

    if (isCompleted) {
      await DatabaseHelper.instance.markHabitIncomplete(
        habit.id!,
        DateTime.now(),
      );
    } else {
      await DatabaseHelper.instance.markHabitCompleted(
        habit.id!,
        DateTime.now(),
      );
    }

    await _loadHabits();
  }

  // DELETE HABIT

  Future<void> _deleteHabit(HabitModel habit) async {
    if (habit.id == null) return;

    await NotificationService.instance.cancelNotification(habit.id! + 200000);

    await DatabaseHelper.instance.deleteHabit(habit.id!);

    await _loadHabits();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Habit deleted successfully.')),
    );
  }

  // CREATE OR EDIT HABIT

  Future<void> _showHabitDialog({HabitModel? habit}) async {
    final nameController = TextEditingController(text: habit?.name ?? '');

    final descriptionController = TextEditingController(
      text: habit?.description ?? '',
    );

    String selectedCategory = categories.contains(habit?.category)
        ? habit!.category
        : categories.first;

    TimeOfDay? selectedReminderTime = _parseReminderTime(habit?.reminderTime);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              title: Text(
                habit == null ? 'Create Habit' : 'Edit Habit',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Habit Name',
                        hintText: 'e.g. Read 10 pages',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Add a short description',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 18),

                    // DAILY REMINDER TIME
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.softGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                color: AppColors.forestGreen,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Daily Reminder',
                                style: TextStyle(
                                  color: AppColors.forestGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selectedReminderTime == null
                                      ? 'No reminder set'
                                      : 'Every day at ${selectedReminderTime!.format(context)}',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final pickedTime = await showTimePicker(
                                    context: dialogContext,
                                    initialTime:
                                        selectedReminderTime ?? TimeOfDay.now(),
                                  );

                                  if (pickedTime != null) {
                                    setDialogState(() {
                                      selectedReminderTime = pickedTime;
                                    });
                                  }
                                },
                                child: Text(
                                  selectedReminderTime == null
                                      ? 'Set time'
                                      : 'Change',
                                  style: const TextStyle(
                                    color: AppColors.forestGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (selectedReminderTime != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    selectedReminderTime = null;
                                  });
                                },
                                child: const Text(
                                  'Remove reminder',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a habit name.'),
                        ),
                      );
                      return;
                    }

                    // Ask permission before saving a reminder.
                    if (selectedReminderTime != null) {
                      final permission = await NotificationService.instance
                          .requestPermission();

                      if (permission == false) {
                        if (!dialogContext.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notification permission is required for reminders.',
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    final reminderTime = selectedReminderTime == null
                        ? null
                        : _formatTime(selectedReminderTime!);

                    if (habit == null) {
                      final newHabit = HabitModel(
                        name: name,
                        description: descriptionController.text.trim(),
                        category: selectedCategory,
                        reminderTime: reminderTime,
                      );

                      final insertedId = await DatabaseHelper.instance
                          .insertHabit(newHabit);

                      final savedHabit = newHabit.copyWith(id: insertedId);

                      await _syncHabitNotification(savedHabit);
                    } else {
                      final updatedHabit = habit.copyWith(
                        name: name,
                        description: descriptionController.text.trim(),
                        category: selectedCategory,
                        reminderTime: reminderTime,
                        clearReminderTime: reminderTime == null,
                      );

                      await DatabaseHelper.instance.updateHabit(updatedHabit);

                      await _syncHabitNotification(updatedHabit);
                    }

                    if (!dialogContext.mounted) return;

                    Navigator.pop(dialogContext);
                    await _loadHabits();

                    if (!mounted) return;

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          selectedReminderTime == null
                              ? 'Habit saved successfully.'
                              : 'Habit saved with daily reminder.',
                        ),
                      ),
                    );
                  },
                  child: Text(habit == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
  }

  // MAIN SCREEN

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHabits,
          color: AppColors.oliveGreen,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Habits',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Small steps, big changes.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _showHabitDialog(),
                    icon: const Icon(
                      Icons.add_circle,
                      color: AppColors.forestGreen,
                      size: 34,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildProgressCard(),

              const SizedBox(height: 26),

              _buildWeeklyCalendar(),

              const SizedBox(height: 26),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Habits",
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '$completedCount/${habits.length} completed',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (habits.isEmpty)
                _buildEmptyState()
              else
                ...habits.map(_buildHabitCard),
            ],
          ),
        ),
      ),
    );
  }

  // PROGRESS CARD

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.forestGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Progress",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(
                Icons.flag_rounded,
                color: AppColors.softLime,
                size: 30,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(AppColors.softLime),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$completedCount out of ${habits.length} habits completed',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // WEEKLY HABIT CALENDAR

  Widget _buildWeeklyCalendar() {
    final weekDates = currentWeekDates;

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Overview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${weekDates.first.day} - ${weekDates.last.day}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: List.generate(7, (index) {
              final date = weekDates[index];
              final isToday = date == todayDate;

              return Expanded(
                child: Column(
                  children: [
                    Text(
                      dayNames[index],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? AppColors.forestGreen
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 30,
                      width: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.softLime
                            : AppColors.softGreen,
                        shape: BoxShape.circle,
                        border: isToday
                            ? Border.all(
                                color: AppColors.oliveGreen,
                                width: 1.3,
                              )
                            : null,
                      ),
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.forestGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

          const SizedBox(height: 18),

          const Divider(color: AppColors.border),

          const SizedBox(height: 10),

          if (habits.isEmpty)
            const Text(
              'Create habits to see your weekly progress.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            )
          else
            ...habits.map((habit) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    ...weekDates.map((date) {
                      final isCompleted = _isCompletedOnDate(habit, date);

                      final isFuture = date.isAfter(todayDate);

                      return Expanded(
                        child: Center(
                          child: Container(
                            height: 19,
                            width: 19,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? AppColors.oliveGreen
                                  : AppColors.softGreen,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isFuture
                                    ? AppColors.border
                                    : Colors.transparent,
                              ),
                            ),
                            child: isCompleted
                                ? const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),

          const SizedBox(height: 2),

          Row(
            children: [
              Container(
                height: 9,
                width: 9,
                decoration: const BoxDecoration(
                  color: AppColors.oliveGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Completed',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 14),
              Container(
                height: 9,
                width: 9,
                decoration: const BoxDecoration(
                  color: AppColors.softGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Not completed',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // HABIT CARD

  Widget _buildHabitCard(HabitModel habit) {
    final isCompleted = completedHabits[habit.id] ?? false;

    final currentStreak = habitStreaks[habit.id]?['current'] ?? 0;

    final bestStreak = habitStreaks[habit.id]?['best'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleHabit(habit),
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.oliveGreen : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.oliveGreen, width: 1.5),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),

                if (habit.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    habit.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],

                const SizedBox(height: 7),

                Text(
                  habit.category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.oliveGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                // SHOW DAILY REMINDER TIME
                if (habit.reminderTime != null &&
                    habit.reminderTime!.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        size: 14,
                        color: AppColors.oliveGreen,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Daily at ${_displayReminderTime(habit.reminderTime!)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.oliveGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),

                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 17,
                          color: Color(0xFFD98A42),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$currentStreak day streak',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 16,
                          color: Color(0xFFB99A43),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Best: $bestStreak days',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                TextButton.icon(
                  onPressed: () => _openHabitHistory(habit),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 4,
                    ),
                    foregroundColor: AppColors.forestGreen,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: const Text(
                    'View History',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showHabitDialog(habit: habit);
              } else if (value == 'delete') {
                _deleteHabit(habit);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  // EMPTY STATE

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.track_changes_rounded,
            size: 48,
            color: AppColors.oliveGreen,
          ),
          SizedBox(height: 14),
          Text(
            'No habits yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Create your first habit and start building consistency.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
