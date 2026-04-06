import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../notification_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController =
      TextEditingController();
  String _selectedInstrument = 'Guitar';
  bool _isDarkMode = true;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime =
      const TimeOfDay(hour: 9, minute: 0);

  final List<String> _instruments = [
    'Guitar', 'Piano', 'Violin', 'Viola', 'Cello',
    'Bass', 'Drums', 'Voice', 'Trumpet', 'Flute',
    'Saxophone', 'Clarinet', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final reminderSettings =
        await NotificationHelper.getReminderSettings();
    setState(() {
      _nameController.text =
          prefs.getString('userName') ?? 'Musician';
      _selectedInstrument =
          prefs.getString('instrument') ?? 'Guitar';
      _isDarkMode = prefs.getBool('darkMode') ?? true;
      _reminderEnabled =
          reminderSettings['enabled'] ?? false;
      _reminderTime = TimeOfDay(
        hour: reminderSettings['hour'] ?? 9,
        minute: reminderSettings['minute'] ?? 0,
      );
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'userName',
        _nameController.text.trim().isEmpty
            ? 'Musician'
            : _nameController.text.trim());
    await prefs.setString(
        'instrument', _selectedInstrument);
    await prefs.setBool('darkMode', _isDarkMode);

    if (_reminderEnabled) {
      final granted =
          await NotificationHelper.requestPermission();
      if (granted) {
        await NotificationHelper.scheduleDailyReminder(
          hour: _reminderTime.hour,
          minute: _reminderTime.minute,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Reminder set for ${_formatTime(_reminderTime)}!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Permission denied — go to iPhone Settings → Zyntune → Notifications and enable them'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      await NotificationHelper.cancelReminders();
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'Set Practice Reminder Time',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: false,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: const TimePickerThemeData(
                entryModeIconColor: Colors.transparent,
              ),
            ),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _resetAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text(
            'This will delete all practice sessions, goals, songs and notes. This cannot be undone!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await NotificationHelper.cancelReminders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data reset.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0
        ? 12
        : time.hourOfPeriod;
    final minute =
        time.minute.toString().padLeft(2, '0');
    final period =
        time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Profile Section ---
            Text('Profile',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.onSurface
                    .withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedInstrument,
                    decoration: const InputDecoration(
                      labelText: 'Your Instrument',
                      border: OutlineInputBorder(),
                      prefixIcon:
                          Icon(Icons.music_note),
                    ),
                    items: _instruments
                        .map((i) => DropdownMenuItem(
                              value: i,
                              child: Text(i),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() =>
                            _selectedInstrument = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Reminders Section ---
            Text('Practice Reminders',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.onSurface
                    .withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications,
                              color: colorScheme.primary),
                          const SizedBox(width: 12),
                          const Text('Daily Reminder',
                              style: TextStyle(
                                  fontSize: 16)),
                        ],
                      ),
                      Switch(
                        value: _reminderEnabled,
                        onChanged: (val) => setState(
                            () => _reminderEnabled = val),
                        activeThumbColor:
                            colorScheme.primary,
                      ),
                    ],
                  ),
                  if (_reminderEnabled) ...[
                    const Divider(),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                color:
                                    colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text('Reminder Time',
                                style: TextStyle(
                                    fontSize: 16)),
                          ],
                        ),
                        TextButton(
                          onPressed: _pickReminderTime,
                          child: Text(
                            _formatTime(_reminderTime),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple
                            .withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16,
                              color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Notification fires when the app is closed or in the background.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.deepPurple),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Appearance Section ---
            Text('Appearance',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.onSurface
                    .withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isDark
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isDark
                            ? 'Dark Mode'
                            : 'Light Mode',
                        style: const TextStyle(
                            fontSize: 16),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isDarkMode,
                    onChanged: (val) {
                      setState(() => _isDarkMode = val);
                      ZyntuneApp.of(context)
                          ?.toggleTheme();
                    },
                    activeThumbColor: colorScheme.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- About Section ---
            Text('About',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.onSurface
                    .withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  _SettingsRow(
                    icon: Icons.music_note,
                    label: 'Zyntune',
                    value: 'Version 1.0.0',
                  ),
                  Divider(),
                  _SettingsRow(
                    icon: Icons.info_outline,
                    label: 'Built with Flutter',
                    value: '',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Save Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Settings',
                    style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Danger Zone ---
            Text('Danger Zone',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.withOpacity(0.8))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetAllData,
                icon: const Icon(Icons.delete_forever,
                    color: Colors.red),
                label: const Text('Reset All Data',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16),
                  side: const BorderSide(
                      color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color:
                  Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 15)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5))),
        ],
      ),
    );
  }
}