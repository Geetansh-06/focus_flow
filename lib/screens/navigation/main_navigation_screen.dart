import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../home/home_screen.dart';
import '../tasks/tasks_screen.dart';
import '../focus/focus_screen.dart';
import '../habits/habits_screen.dart';
import '../analytics/analytics_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final GlobalKey<HomeScreenState> _homeKey =
  GlobalKey<HomeScreenState>();

  final GlobalKey<TasksScreenState> _tasksKey =
  GlobalKey<TasksScreenState>();

  final GlobalKey<FocusScreenState> _focusKey =
  GlobalKey<FocusScreenState>();

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      _homeKey.currentState?.refreshTasks();
    }

    if (index == 1) {
      _tasksKey.currentState?.refreshTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        key: _homeKey,
        onAddTask: () => _selectTab(1),
        onStartFocus: () => _selectTab(2),
        onTrackHabit: () => _selectTab(3),
        onTaskChanged: () {
          _tasksKey.currentState?.refreshTasks();
        },
      ),

      TasksScreen(key: _tasksKey),

      FocusScreen(
        key: _focusKey,
        onSessionCompleted: () {
          _homeKey.currentState?.refreshTasks();
        },
      ),

      const HabitsScreen(),

      const AnalyticsScreen(),

      const ProfileScreen(),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,

      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(
            top: BorderSide(
              color: AppColors.border,
            ),
          ),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _selectTab,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.card,
            selectedItemColor: AppColors.forestGreen,
            unselectedItemColor: AppColors.textSecondary,
            selectedFontSize: 10,
            unselectedFontSize: 10,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.checklist_rounded),
                label: 'Tasks',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.timer_rounded),
                label: 'Focus',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.track_changes_rounded),
                label: 'Habits',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics_rounded),
                label: 'Analytics',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
