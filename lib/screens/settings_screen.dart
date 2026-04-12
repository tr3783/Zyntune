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
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

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
      _reminderEnabled = reminderSettings['enabled'] ?? false;
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
    await prefs.setString('instrument', _selectedInstrument);
    await prefs.setBool('darkMode', _isDarkMode);

    if (_reminderEnabled) {
      final granted = await NotificationHelper.requestPermission();
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
                  'Permission denied — go to iPhone Settings → Zyntune → Notifications'),
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
          data: MediaQuery.of(context)
              .copyWith(alwaysUse24HourFormat: false),
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
        backgroundColor: _cardBg,
        title: const Text('Reset All Data',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This will delete all practice sessions, goals, songs and notes. This cannot be undone!',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
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
    final hour =
        time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period =
        time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _darkBg : const Color(0xFFF5F0FF),
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_purple, Color(0xFF9B59B6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Profile Section ---
            _SectionHeader(label: 'Profile', icon: Icons.person_outline),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Your Name',
                      labelStyle: TextStyle(
                          color: isDark
                              ? Colors.white60
                              : Colors.black54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: _purple.withOpacity(0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: _purple.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _purple),
                      ),
                      prefixIcon: Icon(Icons.person,
                          color: isDark
                              ? Colors.white54
                              : Colors.black38),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedInstrument,
                    dropdownColor:
                        isDark ? _cardBg : Colors.white,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Your Instrument',
                      labelStyle: TextStyle(
                          color: isDark
                              ? Colors.white60
                              : Colors.black54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: _purple.withOpacity(0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: _purple.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _purple),
                      ),
                      prefixIcon: Icon(Icons.music_note,
                          color: isDark
                              ? Colors.white54
                              : Colors.black38),
                    ),
                    items: _instruments
                        .map((i) => DropdownMenuItem(
                              value: i,
                              child: Text(i),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(
                            () => _selectedInstrument = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Reminders Section ---
            _SectionHeader(
                label: 'Practice Reminders',
                icon: Icons.notifications_outlined),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _purple.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.notifications_outlined,
                                color: _purple,
                                size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Daily Reminder',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _reminderEnabled,
                        onChanged: (val) => setState(
                            () => _reminderEnabled = val),
                        activeColor: _purple,
                      ),
                    ],
                  ),
                  if (_reminderEnabled) ...[
                    const SizedBox(height: 12),
                    Divider(
                        color: _purple.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal
                                    .withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.access_time,
                                  color: Colors.teal,
                                  size: 18),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Reminder Time',
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _pickReminderTime,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  _purple,
                                  Color(0xFF9B59B6)
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            child: Text(
                              _formatTime(_reminderTime),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _purple.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                _purple.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: _purple),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Notification fires when the app is closed or in the background.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9B59B6)),
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
            _SectionHeader(
                label: 'Appearance',
                icon: Icons.palette_outlined),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          color: isDark
                              ? Colors.white70
                              : Colors.black54,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isDark ? 'Dark Mode' : 'Light Mode',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isDarkMode,
                    onChanged: (val) {
                      setState(() => _isDarkMode = val);
                      ZyntuneApp.of(context)?.toggleTheme();
                    },
                    activeColor: _purple,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- About Section ---
            _SectionHeader(
                label: 'About', icon: Icons.info_outline),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(
                children: [
                  _AboutRow(
                    icon: Icons.music_note,
                    label: 'Zyntune',
                    value: 'Version 1.0.0',
                    color: _purple,
                    isDark: isDark,
                  ),
                  Divider(color: _purple.withOpacity(0.2)),
                  _AboutRow(
                    icon: Icons.code,
                    label: 'Built with Flutter',
                    value: '💙',
                    color: const Color(0xFF2196F3),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // --- Save Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.check_rounded,
                    size: 20),
                label: const Text('Save Settings',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(18)),
                  elevation: 4,
                  shadowColor: _purple.withOpacity(0.4),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Danger Zone ---
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.withOpacity(0.8),
                    size: 18),
                const SizedBox(width: 8),
                Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _resetAllData,
                icon: const Icon(Icons.delete_forever,
                    size: 20),
                label: const Text('Reset All Data',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.red.withOpacity(0.12),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                        color: Colors.red.withOpacity(0.5)),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionHeader(
      {required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF6B21FF).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 16, color: const Color(0xFF6B21FF)),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);
  static const _purple = Color(0xFF6B21FF);

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [_cardBg, _cardBg2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _purple.withOpacity(isDark ? 0.3 : 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _AboutRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 13,
                color:
                    isDark ? Colors.white54 : Colors.black45),
          ),
        ],
      ),
    );
  }
}