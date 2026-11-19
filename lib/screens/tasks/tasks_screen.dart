import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../database/database_helper.dart';
import '../../models/task_model.dart';
import '../../services/notification_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  String selectedFilter = 'All';
  String selectedCategory = 'All';
  String selectedPriority = 'All';
  String selectedSort = 'Recently Added';

  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';

  List<Map<String, dynamic>> tasks = [];
  bool isLoading = true;
  bool isRefreshing = false;

  final List<String> categories = [
    'Work',
    'Personal',
    'Learning',
    'Health',
    'Other',
  ];

  final List<String> priorities = ['Low', 'Medium', 'High'];

  final List<String> sortOptions = [
    'Recently Added',
    'Oldest First',
    'Due Date',
    'Priority',
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final savedTasks = await DatabaseHelper.instance.getTasks();

      if (!mounted) return;

      setState(() {
        tasks = savedTasks.map((task) {
          return {
            'id': task.id,
            'title': task.title,
            'description': task.description,
            'category': task.category,
            'priority': task.priority,
            'completed': task.completed,
            'dueDate': task.dueDate,
            'reminderDateTime': task.reminderDateTime,
            'createdAt': task.createdAt,
          };
        }).toList();

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load tasks: $e')),
      );
    }
  }

  Future<void> refreshTasks() async {
    if (isRefreshing) return;

    setState(() => isRefreshing = true);

    try {
      final savedTasks = await DatabaseHelper.instance.getTasks();

      if (!mounted) return;

      setState(() {
        tasks = savedTasks.map((task) {
          return {
            'id': task.id,
            'title': task.title,
            'description': task.description,
            'category': task.category,
            'priority': task.priority,
            'completed': task.completed,
            'dueDate': task.dueDate,
            'reminderDateTime': task.reminderDateTime,
            'createdAt': task.createdAt,
          };
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to refresh tasks: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isRefreshing = false);
      }
    }
  }

  List<Map<String, dynamic>> get filteredTasks {
    List<Map<String, dynamic>> result = tasks.where((task) {
      final matchesStatus =
          selectedFilter == 'All' ||
              (selectedFilter == 'Pending' && task['completed'] == false) ||
              (selectedFilter == 'Completed' && task['completed'] == true);

      final matchesCategory =
          selectedCategory == 'All' ||
              task['category'] == selectedCategory;

      final matchesPriority =
          selectedPriority == 'All' ||
              task['priority'] == selectedPriority;

      final title = (task['title'] ?? '').toString().toLowerCase();
      final description =
      (task['description'] ?? '').toString().toLowerCase();

      final query = searchQuery.trim().toLowerCase();

      final matchesSearch =
          query.isEmpty ||
              title.contains(query) ||
              description.contains(query);

      return matchesStatus &&
          matchesCategory &&
          matchesPriority &&
          matchesSearch;
    }).toList();

    if (selectedSort == 'Oldest First') {
      result.sort((a, b) {
        final dateA = a['createdAt'] as DateTime;
        final dateB = b['createdAt'] as DateTime;
        return dateA.compareTo(dateB);
      });
    } else if (selectedSort == 'Due Date') {
      result.sort((a, b) {
        final dateA = a['dueDate'] as DateTime?;
        final dateB = b['dueDate'] as DateTime?;

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateA.compareTo(dateB);
      });
    } else if (selectedSort == 'Priority') {
      const priorityOrder = {'High': 0, 'Medium': 1, 'Low': 2};

      result.sort((a, b) {
        return (priorityOrder[a['priority']] ?? 3).compareTo(
          priorityOrder[b['priority']] ?? 3,
        );
      });
    } else {
      result.sort((a, b) {
        final dateA = a['createdAt'] as DateTime;
        final dateB = b['createdAt'] as DateTime;
        return dateB.compareTo(dateA);
      });
    }

    return result;
  }

  int get completedCount =>
      tasks.where((task) => task['completed'] == true).length;

  void _resetFilters() {
    setState(() {
      selectedFilter = 'All';
      selectedCategory = 'All';
      selectedPriority = 'All';
      selectedSort = 'Recently Added';
      searchQuery = '';
      searchController.clear();
    });
  }

  Future<void> _showTaskDialog({Map<String, dynamic>? task}) async {
    final isEditing = task != null;

    final titleController = TextEditingController(
      text: task?['title'] ?? '',
    );

    final descriptionController = TextEditingController(
      text: task?['description'] == 'No description'
          ? ''
          : task?['description'] ?? '',
    );

    String category = task?['category'] ?? 'Personal';
    String priority = task?['priority'] ?? 'Medium';
    DateTime? dueDate = task?['dueDate'] as DateTime?;
    DateTime? reminderDateTime =
    task?['reminderDateTime'] as DateTime?;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                isEditing ? 'Edit Task' : 'Add New Task',
                style: const TextStyle(
                  color: AppColors.forestGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: _inputDecoration('Task Title'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: _inputDecoration('Description'),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: _inputDecoration('Category'),
                      items: categories.map((value) {
                        return DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => category = value);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: _inputDecoration('Priority'),
                      items: priorities.map((value) {
                        return DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => priority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    _buildDialogLabel('Due Date'),
                    const SizedBox(height: 8),
                    _buildDateSelector(
                      context: dialogContext,
                      date: dueDate,
                      placeholder: 'Select Due Date',
                      icon: Icons.calendar_today_rounded,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: dueDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.forestGreen,
                                  onPrimary: Colors.white,
                                  surface: AppColors.card,
                                  onSurface: AppColors.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (picked != null) {
                          setDialogState(() {
                            dueDate = DateUtils.dateOnly(picked);
                          });
                        }
                      },
                      onClear: () {
                        setDialogState(() => dueDate = null);
                      },
                    ),
                    const SizedBox(height: 18),
                    _buildDialogLabel('Task Reminder'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();

                        final suggestedDate =
                        reminderDateTime != null &&
                            reminderDateTime!.isAfter(now)
                            ? reminderDateTime!
                            : now.add(const Duration(minutes: 5));

                        final pickedDate = await showDatePicker(
                          context: dialogContext,
                          initialDate: DateUtils.dateOnly(suggestedDate),
                          firstDate: DateUtils.dateOnly(now),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.forestGreen,
                                  onPrimary: Colors.white,
                                  surface: AppColors.card,
                                  onSurface: AppColors.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedDate == null ||
                            !dialogContext.mounted) {
                          return;
                        }

                        final initialTime =
                        reminderDateTime != null &&
                            DateUtils.isSameDay(
                              reminderDateTime,
                              pickedDate,
                            )
                            ? TimeOfDay.fromDateTime(
                          reminderDateTime!,
                        )
                            : TimeOfDay.fromDateTime(
                          suggestedDate,
                        );

                        final pickedTime = await showTimePicker(
                          context: dialogContext,
                          initialTime: initialTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.forestGreen,
                                  onPrimary: Colors.white,
                                  surface: AppColors.card,
                                  onSurface: AppColors.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedTime == null ||
                            !dialogContext.mounted) {
                          return;
                        }

                        final selectedReminder = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );

                        if (!selectedReminder.isAfter(DateTime.now())) {
                          ScaffoldMessenger.of(
                            dialogContext,
                          ).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select a future reminder time.',
                              ),
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          reminderDateTime = selectedReminder;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_active_outlined,
                              size: 19,
                              color: AppColors.oliveGreen,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                reminderDateTime == null
                                    ? 'Set Reminder Date & Time'
                                    : '${MaterialLocalizations.of(context).formatMediumDate(reminderDateTime!)} · ${TimeOfDay.fromDateTime(reminderDateTime!).format(context)}',
                                style: TextStyle(
                                  color: reminderDateTime == null
                                      ? AppColors.textSecondary
                                      : AppColors.forestGreen,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (reminderDateTime != null)
                              IconButton(
                                onPressed: () {
                                  setDialogState(
                                        () => reminderDateTime = null,
                                  );
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 19,
                                  color: AppColors.error,
                                ),
                              )
                            else
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: AppColors.textSecondary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusScope.of(dialogContext).unfocus();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final description =
                    descriptionController.text.trim();

                    if (title.isEmpty) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter task title'),
                        ),
                      );
                      return;
                    }

                    FocusScope.of(dialogContext).unfocus();
                    Navigator.pop(dialogContext, {
                      'title': title,
                      'description': description.isEmpty
                          ? 'No description'
                          : description,
                      'category': category,
                      'priority': priority,
                      'dueDate': dueDate,
                      'reminderDateTime': reminderDateTime,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    isEditing ? 'Update Task' : 'Save Task',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // Let the dialog's reverse transition finish before disposing controllers.
    // Otherwise TextField may still be listening to them during the closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    titleController.dispose();
    descriptionController.dispose();

    if (result == null || !mounted) return;

    try {
      if (isEditing) {
        final updatedTask = TaskModel(
          id: task['id'] as int,
          title: result['title'] as String,
          description: result['description'] as String,
          category: result['category'] as String,
          priority: result['priority'] as String,
          completed: task['completed'] as bool,
          dueDate: result['dueDate'] as DateTime?,
          reminderDateTime:
          result['reminderDateTime'] as DateTime?,
          createdAt: task['createdAt'] as DateTime,
        );

        await DatabaseHelper.instance.updateTask(updatedTask);
        await _syncTaskNotification(updatedTask);

        if (!mounted) return;

        setState(() {
          task.addAll(result);
        });
      } else {
        final newTask = TaskModel(
          title: result['title'] as String,
          description: result['description'] as String,
          category: result['category'] as String,
          priority: result['priority'] as String,
          completed: false,
          dueDate: result['dueDate'] as DateTime?,
          reminderDateTime:
          result['reminderDateTime'] as DateTime?,
        );

        final newId =
        await DatabaseHelper.instance.insertTask(newTask);

        final savedTask = TaskModel(
          id: newId,
          title: newTask.title,
          description: newTask.description,
          category: newTask.category,
          priority: newTask.priority,
          completed: newTask.completed,
          dueDate: newTask.dueDate,
          reminderDateTime: newTask.reminderDateTime,
          createdAt: newTask.createdAt,
        );

        await _syncTaskNotification(savedTask);

        if (!mounted) return;

        setState(() {
          tasks.insert(0, {
            ...result,
            'id': newId,
            'completed': false,
            'createdAt': newTask.createdAt,
          });
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Task updated successfully!'
                : 'Task added successfully!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save task: $e')),
      );
    }
  }

  Widget _buildDialogLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDateSelector({
    required BuildContext context,
    required DateTime? date,
    required String placeholder,
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.oliveGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                date == null
                    ? placeholder
                    : MaterialLocalizations.of(
                  context,
                ).formatMediumDate(date),
                style: TextStyle(
                  color: date == null
                      ? AppColors.textSecondary
                      : AppColors.forestGreen,
                  fontSize: 13,
                ),
              ),
            ),
            if (date != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 19,
                  color: AppColors.error,
                ),
                tooltip: 'Remove Date',
              )
            else
              const Icon(
                Icons.arrow_drop_down_rounded,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncTaskNotification(TaskModel task) async {
    if (task.id == null) return;

    try {
      final reminder = task.reminderDateTime;

      if (task.completed ||
          reminder == null ||
          !reminder.isAfter(DateTime.now())) {
        await NotificationService.instance.cancelNotification(
          task.id!,
        );
        return;
      }

      await NotificationService.instance.scheduleNotification(
        id: task.id!,
        title: 'Task Reminder: ${task.title}',
        body: task.description == 'No description'
            ? 'You have a task to complete.'
            : task.description,
        scheduledDate: reminder,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Task saved, but reminder could not be set: $e',
          ),
        ),
      );
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            'Delete Task?',
            style: TextStyle(
              color: AppColors.forestGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete this task?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await DatabaseHelper.instance.deleteTask(task['id'] as int);

      await NotificationService.instance.cancelNotification(
        task['id'] as int,
      );

      if (!mounted) return;

      setState(() {
        tasks.removeWhere((item) => item['id'] == task['id']);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete task: $e')),
      );
    }
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final updatedTask = TaskModel(
      id: task['id'] as int,
      title: task['title'] as String,
      description: task['description'] as String,
      category: task['category'] as String,
      priority: task['priority'] as String,
      completed: !(task['completed'] as bool),
      dueDate: task['dueDate'] as DateTime?,
      reminderDateTime:
      task['reminderDateTime'] as DateTime?,
      createdAt: task['createdAt'] as DateTime,
    );

    try {
      await DatabaseHelper.instance.updateTask(updatedTask);
      await _syncTaskNotification(updatedTask);

      if (!mounted) return;

      setState(() {
        task['completed'] = updatedTask.completed;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update task: $e')),
      );
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
      ),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.oliveGreen,
          width: 1.5,
        ),
      ),
    );
  }

  bool _isOverdue(Map<String, dynamic> task) {
    final dueDate = task['dueDate'] as DateTime?;

    if (dueDate == null || task['completed'] == true) {
      return false;
    }

    return dueDate.isBefore(DateUtils.dateOnly(DateTime.now()));
  }




  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen =
        MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isKeyboardOpen) _buildHeader(),

            if (!isKeyboardOpen) ...[
              _buildSummary(),
              _buildStatusFilters(),
            ],

            _buildSearchField(),

            if (!isKeyboardOpen) _buildAdvancedFilters(),

            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.oliveGreen,
                ),
              )
                  : RefreshIndicator(
                color: AppColors.oliveGreen,
                onRefresh: refreshTasks,
                child: filteredTasks.isEmpty
                    ? ListView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    SizedBox(
                      height: 240,
                      child: _buildEmptyState(),
                    ),
                  ],
                )
                    : ListView.builder(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    100,
                  ),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(
                      filteredTasks[index],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isKeyboardOpen
          ? null
          : FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Task',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }




  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay Organized',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'My Tasks',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestGreen,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: AppColors.forestGreen,
              size: 27,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final pendingCount = tasks.length - completedCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.forestGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              'Total Tasks',
              '${tasks.length}',
            ),
          ),
          Container(
            height: 45,
            width: 1,
            color: AppColors.sageGreen,
          ),
          Expanded(
            child: _buildSummaryItem(
              'Completed',
              '$completedCount',
            ),
          ),
          Container(
            height: 45,
            width: 1,
            color: AppColors.sageGreen,
          ),
          Expanded(
            child: _buildSummaryItem(
              'Pending',
              '$pendingCount',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.sageGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilters() {
    final filters = ['All', 'Pending', 'Completed'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: filters.map((filter) {
          final isSelected = selectedFilter == filter;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => selectedFilter = filter);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.forestGreen
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.forestGreen
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  filter,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          setState(() => searchQuery = value);
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search tasks by title or description...',
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.oliveGreen,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
            onPressed: () {
              searchController.clear();
              setState(() => searchQuery = '');
            },
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
            ),
          )
              : null,
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.oliveGreen,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filter & Sort',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.oliveGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  value: selectedCategory,
                  label: 'Category',
                  options: ['All', ...categories],
                  onChanged: (value) {
                    setState(() => selectedCategory = value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  value: selectedPriority,
                  label: 'Priority',
                  options: ['All', ...priorities.reversed],
                  onChanged: (value) {
                    setState(() => selectedPriority = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDropdown(
            value: selectedSort,
            label: 'Sort By',
            options: sortOptions,
            onChanged: (value) {
              setState(() => selectedSort = value);
            },
          ),
          const SizedBox(height: 4),
          Text(
            '${filteredTasks.length} of ${tasks.length} tasks',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      items: options.map((option) {
        return DropdownMenuItem(
          value: option,
          child: Text(
            option,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null) onChanged(newValue);
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final isCompleted = task['completed'] as bool;
    final dueDate = task['dueDate'] as DateTime?;
    final reminderDateTime =
    task['reminderDateTime'] as DateTime?;
    final isOverdue = _isOverdue(task);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _toggleTask(task),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: isCompleted
                    ? AppColors.success
                    : AppColors.textSecondary,
                size: 25,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] as String,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestGreen,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  task['description'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTag(task['category'] as String),
                    _buildTag(task['priority'] as String),
                  ],
                ),
                if (dueDate != null) ...[
                  const SizedBox(height: 10),
                  _buildDueDate(dueDate, isOverdue),
                ],
                if (reminderDateTime != null && !isCompleted) ...[
                  const SizedBox(height: 8),
                  _buildReminderDateTime(reminderDateTime),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            color: AppColors.card,
            onSelected: (value) {
              if (value == 'edit') {
                _showTaskDialog(task: task);
              } else if (value == 'delete') {
                _deleteTask(task);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_rounded,
                      size: 19,
                      color: AppColors.forestGreen,
                    ),
                    SizedBox(width: 10),
                    Text('Edit Task'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Delete Task',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderDateTime(DateTime reminderDateTime) {
    final dateText = MaterialLocalizations.of(
      context,
    ).formatMediumDate(reminderDateTime);

    final timeText =
    TimeOfDay.fromDateTime(reminderDateTime).format(context);

    return Row(
      children: [
        const Icon(
          Icons.notifications_active_outlined,
          size: 15,
          color: AppColors.oliveGreen,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            'Reminder · $dateText at $timeText',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.oliveGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDueDate(DateTime dueDate, bool isOverdue) {
    final dateText = MaterialLocalizations.of(
      context,
    ).formatMediumDate(dueDate);

    final color = isOverdue
        ? AppColors.error
        : AppColors.oliveGreen;

    return Row(
      children: [
        Icon(
          Icons.calendar_month_rounded,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            isOverdue ? 'Overdue · $dateText' : 'Due · $dateText',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.forestGreen,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final noTasksAtAll = tasks.isEmpty;
    final hasSearch = searchQuery.trim().isNotEmpty;

    final title = noTasksAtAll
        ? 'No tasks yet'
        : hasSearch
        ? 'No matching tasks'
        : 'No tasks found';

    final description = noTasksAtAll
        ? 'Start organizing your day by adding your first task.'
        : hasSearch
        ? 'Try another keyword to find your task.'
        : 'Try changing your filters to see more tasks.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 76,
              width: 76,
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                noTasksAtAll
                    ? Icons.add_task_rounded
                    : Icons.search_off_rounded,
                size: 38,
                color: AppColors.oliveGreen,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.forestGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            if (noTasksAtAll)
              ElevatedButton.icon(
                onPressed: () => _showTaskDialog(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Your First Task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Clear Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forestGreen,
                  side: const BorderSide(
                    color: AppColors.oliveGreen,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}