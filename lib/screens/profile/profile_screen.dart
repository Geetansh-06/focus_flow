
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../services/notification_service.dart';
import '../../services/backup_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = 'FocusFlow User';
  String userEmail = 'Add your email';

  bool isLoading = true;
  bool isRequestingPermission = false;
  bool isSendingTestNotification = false;

  bool taskNotificationsEnabled = true;
  bool habitNotificationsEnabled = true;
  bool focusNotificationsEnabled = true;

  bool isUpdatingTaskNotification = false;
  bool isUpdatingHabitNotification = false;
  bool isUpdatingFocusNotification = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    final taskEnabled =
    await NotificationService.instance.areTaskNotificationsEnabled();

    final habitEnabled =
    await NotificationService.instance.areHabitNotificationsEnabled();

    final focusEnabled =
    await NotificationService.instance.areFocusNotificationsEnabled();

    if (!mounted) return;

    setState(() {
      userName = prefs.getString('profile_name') ?? 'FocusFlow User';
      userEmail = prefs.getString('profile_email') ?? 'Add your email';

      taskNotificationsEnabled = taskEnabled;
      habitNotificationsEnabled = habitEnabled;
      focusNotificationsEnabled = focusEnabled;

      isLoading = false;
    });
  }

  Future<void> _saveProfile(String name, String email) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('profile_name', name);
    await prefs.setString('profile_email', email);

    if (!mounted) return;

    setState(() {
      userName = name;
      userEmail = email;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully.'),
      ),
    );
  }

  String get initials {
    final parts = userName.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts.first.isEmpty) return 'F';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ================= NOTIFICATION PERMISSION =================

  Future<bool> _ensureNotificationPermission() async {
    final permission =
    await NotificationService.instance.requestPermission();

    if (permission == false) {
      _showMessage(
        'Notification permission not granted. Please check app settings.',
      );
      return false;
    }

    return true;
  }

  Future<void> _updateNotificationSetting({
    required bool enabled,
    required Future<void> Function(bool) saveSetting,
    required VoidCallback updateState,
    required VoidCallback setLoading,
    required VoidCallback clearLoading,
    required String settingName,
  }) async {
    setState(setLoading);

    try {
      if (enabled) {
        final permissionGranted =
        await _ensureNotificationPermission();

        if (!permissionGranted) return;
      }

      await saveSetting(enabled);

      if (!mounted) return;

      setState(updateState);

      _showMessage(
        '$settingName ${enabled ? 'enabled' : 'disabled'}.',
      );
    } catch (e) {
      _showMessage('Unable to update $settingName: $e');
    } finally {
      if (mounted) {
        setState(clearLoading);
      }
    }
  }

  Future<void> _changeTaskNotifications(bool enabled) async {
    await _updateNotificationSetting(
      enabled: enabled,
      saveSetting:
      NotificationService.instance.setTaskNotificationsEnabled,
      updateState: () {
        taskNotificationsEnabled = enabled;
      },
      setLoading: () {
        isUpdatingTaskNotification = true;
      },
      clearLoading: () {
        isUpdatingTaskNotification = false;
      },
      settingName: 'Task reminders',
    );
  }

  Future<void> _changeHabitNotifications(bool enabled) async {
    await _updateNotificationSetting(
      enabled: enabled,
      saveSetting:
      NotificationService.instance.setHabitNotificationsEnabled,
      updateState: () {
        habitNotificationsEnabled = enabled;
      },
      setLoading: () {
        isUpdatingHabitNotification = true;
      },
      clearLoading: () {
        isUpdatingHabitNotification = false;
      },
      settingName: 'Habit reminders',
    );
  }

  Future<void> _changeFocusNotifications(bool enabled) async {
    await _updateNotificationSetting(
      enabled: enabled,
      saveSetting:
      NotificationService.instance.setFocusNotificationsEnabled,
      updateState: () {
        focusNotificationsEnabled = enabled;
      },
      setLoading: () {
        isUpdatingFocusNotification = true;
      },
      clearLoading: () {
        isUpdatingFocusNotification = false;
      },
      settingName: 'Focus notifications',
    );
  }

  Future<void> _requestNotificationPermission() async {
    setState(() {
      isRequestingPermission = true;
    });

    try {
      final permission =
      await NotificationService.instance.requestPermission();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permission == true
                ? 'Notification permission granted!'
                : 'Notification permission not granted. Please check app settings.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permission error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isRequestingPermission = false;
        });
      }
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() {
      isSendingTestNotification = true;
    });

    try {
      await NotificationService.instance.showNotification(
        id: 1001,
        title: 'FocusFlow Test Notification',
        body: 'Great! Your notifications are working successfully.',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSendingTestNotification = false;
        });
      }
    }
  }

  // ================= BACKUP AND RESTORE =================

  Future<void> _exportBackup() async {
    try {
      final result = await BackupService.instance.exportBackup();

      if (!mounted) return;

      if (result == 'success') {
        _showMessage('Backup exported successfully!');
      } else {
        _showMessage('Backup export cancelled.');
      }
    } catch (e) {
      _showMessage('Backup export failed: $e');
    }
  }

  Future<void> _restoreBackup() async {
    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Restore Backup?',
            style: TextStyle(
              color: AppColors.forestGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Restoring a backup will replace your existing tasks, '
                'focus sessions and habits. This action cannot be undone. '
                'Do you want to continue?',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (shouldRestore != true || !mounted) return;

    try {
      // File picker open hoga aur selected backup restore hoga.
      final restored = await BackupService.instance.restoreBackup();

      // User ne file picker cancel kar diya.
      if (!restored) {
        _showMessage('Backup restore cancelled.');
        return;
      }

      // Successful restore ke baad notifications sync karo.
      try {
        final notificationService = NotificationService.instance;

        final taskEnabled =
        await notificationService.areTaskNotificationsEnabled();

        final habitEnabled =
        await notificationService.areHabitNotificationsEnabled();

        await notificationService.setTaskNotificationsEnabled(
          taskEnabled,
        );

        await notificationService.setHabitNotificationsEnabled(
          habitEnabled,
        );

        if (!mounted) return;

        _showMessage('Backup restored successfully!');
      } catch (e) {
        if (!mounted) return;

        _showMessage(
          'Backup restored, but notification sync failed: $e',
        );
      }
    } catch (e) {
      _showMessage('Backup restore failed: $e');
    }
  }

  // ================= EDIT PROFILE =================

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: userName);

    final emailController = TextEditingController(
      text: userEmail == 'Add your email' ? '' : userEmail,
    );

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              color: AppColors.forestGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration(
                    label: 'Your name',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration(
                    label: 'Email address',
                    icon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }

                    final emailRegex =
                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Enter a valid email address.';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final name = nameController.text.trim();

                final email = emailController.text.trim().isEmpty
                    ? 'Add your email'
                    : emailController.text.trim();

                Navigator.pop(dialogContext);

                await _saveProfile(name, email);
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: AppColors.oliveGreen,
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

  // ================= BUILD =================

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
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage your personal information.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),

              _buildProfileCard(),
              const SizedBox(height: 22),

              _buildInformationCard(),
              const SizedBox(height: 22),

              _buildNotificationCard(),
              const SizedBox(height: 22),

              _buildBackupCard(),
              const SizedBox(height: 22),

              _buildAboutCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ================= PROFILE CARD =================

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.forestGreen,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            height: 88,
            width: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softLime,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 3,
              ),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.forestGreen,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            userEmail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.sageGreen,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showEditProfileDialog,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.sageGreen),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= INFORMATION CARD =================

  Widget _buildInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 18),
          _informationRow(
            icon: Icons.person_outline_rounded,
            label: 'Full Name',
            value: userName,
          ),
          const Divider(height: 25, color: AppColors.border),
          _informationRow(
            icon: Icons.email_outlined,
            label: 'Email Address',
            value: userEmail,
          ),
        ],
      ),
    );
  }

  // ================= NOTIFICATION CARD =================

  Widget _buildNotificationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: AppColors.oliveGreen,
                size: 23,
              ),
              SizedBox(width: 10),
              Text(
                'Notification Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forestGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose which notifications you want to receive.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          _notificationSwitch(
            title: 'Task Reminders',
            subtitle: 'Get notified about upcoming tasks.',
            icon: Icons.task_alt_rounded,
            value: taskNotificationsEnabled,
            isUpdating: isUpdatingTaskNotification,
            onChanged: _changeTaskNotifications,
          ),

          const Divider(height: 18, color: AppColors.border),

          _notificationSwitch(
            title: 'Habit Reminders',
            subtitle: 'Receive daily habit reminders.',
            icon: Icons.repeat_rounded,
            value: habitNotificationsEnabled,
            isUpdating: isUpdatingHabitNotification,
            onChanged: _changeHabitNotifications,
          ),

          const Divider(height: 18, color: AppColors.border),

          _notificationSwitch(
            title: 'Focus Notifications',
            subtitle: 'Get notified when a focus session ends.',
            icon: Icons.timer_outlined,
            value: focusNotificationsEnabled,
            isUpdating: isUpdatingFocusNotification,
            onChanged: _changeFocusNotifications,
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isRequestingPermission
                  ? null
                  : _requestNotificationPermission,
              icon: isRequestingPermission
                  ? const SizedBox(
                height: 17,
                width: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.notifications_outlined),
              label: Text(
                isRequestingPermission
                    ? 'Requesting Permission...'
                    : 'Enable Notifications',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isSendingTestNotification
                  ? null
                  : _sendTestNotification,
              icon: isSendingTestNotification
                  ? const SizedBox(
                height: 17,
                width: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.forestGreen,
                ),
              )
                  : const Icon(Icons.send_rounded),
              label: Text(
                isSendingTestNotification
                    ? 'Sending...'
                    : 'Send Test Notification',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forestGreen,
                side: const BorderSide(
                  color: AppColors.oliveGreen,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= BACKUP CARD =================

  Widget _buildBackupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.backup_outlined,
                color: AppColors.oliveGreen,
                size: 23,
              ),
              SizedBox(width: 10),
              Text(
                'Data Backup & Restore',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forestGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep your productivity data safe. Export a backup '
                'or restore your data whenever needed.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exportBackup,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Export Backup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _restoreBackup,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore Backup'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forestGreen,
                side: const BorderSide(
                  color: AppColors.oliveGreen,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= NOTIFICATION SWITCH =================

  Widget _notificationSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required bool isUpdating,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: AppColors.oliveGreen,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
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
        if (isUpdating)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.oliveGreen,
            ),
          )
        else
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.oliveGreen,
            onChanged: onChanged,
          ),
      ],
    );
  }

  // ================= INFORMATION ROW =================

  Widget _informationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: AppColors.oliveGreen,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forestGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= ABOUT CARD =================

  Widget _buildAboutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.spa_rounded,
            color: AppColors.forestGreen,
            size: 25,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your journey, your progress.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestGreen,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'FocusFlow helps you build better habits, '
                      'stay focused and make every day count.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
