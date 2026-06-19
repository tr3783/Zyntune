import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../notification_helper.dart';
import '../icloud_sync_service.dart';
import '../streak_helper.dart';
import '../purchase_service.dart';
import '../auth_service.dart';
import 'onboarding_screen.dart';
import 'link_teacher_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  List<String> _selectedInstruments = ['Guitar'];
  bool _reminderEnabled = false;
  bool _streakReminderEnabled = true;
  bool _sharePromptEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  String _userRole = 'student';
  String? _linkedTeacherName;

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
    _loadUserRole();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      final role = data?['role'] as String? ?? 'student';
      final teacherId = data?['teacherId'] as String?;

      String? teacherName;
      if (teacherId != null) {
        final teacherDoc = await FirebaseFirestore.instance.collection('users').doc(teacherId).get();
        teacherName = teacherDoc.data()?['name'] as String? ?? 'Your Teacher';
      }

      if (mounted) setState(() {
        _userRole = role;
        _linkedTeacherName = teacherName;
      });
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final reminderSettings = await NotificationHelper.getReminderSettings();
    final instrumentsList = prefs.getStringList('instruments');
    final legacyInstrument = prefs.getString('instrument') ?? 'Guitar';

    setState(() {
      _nameController.text = prefs.getString('userName') ?? 'Musician';
      _selectedInstruments = instrumentsList != null && instrumentsList.isNotEmpty
          ? instrumentsList
          : [legacyInstrument];
      _reminderEnabled = reminderSettings['enabled'] ?? false;
      _streakReminderEnabled = prefs.getBool('streakReminderEnabled') ?? true;
      _sharePromptEnabled = prefs.getBool('sharePromptEnabled') ?? true;
      _reminderTime = TimeOfDay(
        hour: reminderSettings['hour'] ?? 9,
        minute: reminderSettings['minute'] ?? 0,
      );
    });
  }

  Future<void> _saveSettings() async {
    if (_selectedInstruments.isEmpty) _selectedInstruments = ['Guitar'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName',
        _nameController.text.trim().isEmpty ? 'Musician' : _nameController.text.trim());
    await prefs.setStringList('instruments', _selectedInstruments);
    final currentActive = prefs.getString('activeInstrument') ?? _selectedInstruments.first;
    if (!_selectedInstruments.contains(currentActive)) {
      await prefs.setString('activeInstrument', _selectedInstruments.first);
    }
    await prefs.setString('instrument', _selectedInstruments.first);
    await prefs.setBool('sharePromptEnabled', _sharePromptEnabled);
    await prefs.setBool('streakReminderEnabled', _streakReminderEnabled);

    if (_reminderEnabled) {
      final granted = await NotificationHelper.requestPermission();
      if (granted) {
        await NotificationHelper.scheduleDailyReminder(hour: _reminderTime.hour, minute: _reminderTime.minute);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reminder set for ${_formatTime(_reminderTime)}!'), backgroundColor: Colors.green, duration: const Duration(seconds: 3)));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission denied — go to iPhone Settings → Zyntune → Notifications'), backgroundColor: Colors.red, duration: Duration(seconds: 5)));
      }
    } else {
      await NotificationHelper.cancelReminders();
    }

    if (_streakReminderEnabled) {
      final streakData = await StreakHelper.getStreakData();
      await NotificationHelper.scheduleStreakRiskReminder(currentStreak: streakData['currentStreak'] ?? 0);
    } else {
      await NotificationHelper.cancelStreakRiskReminder();
    }

    ICloudSyncService.sync();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'Set Practice Reminder Time',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: Theme(data: Theme.of(context).copyWith(timePickerTheme: const TimePickerThemeData(entryModeIconColor: Colors.transparent)), child: child!),
      ),
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white), child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _resetAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Reset All Data', style: TextStyle(color: Colors.white)),
        content: const Text('This will delete all practice sessions, goals, songs and notes. This cannot be undone!', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Reset Everything')),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await NotificationHelper.cancelReminders();
      await NotificationHelper.cancelStreakRiskReminder();
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const OnboardingScreen()), (route) => false);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final isStudent = _userRole == 'student';
    final isLinked = _linkedTeacherName != null;

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Account ---
            if (user != null) ...[
              _SectionHeader(label: 'Account', icon: Icons.account_circle_outlined),
              const SizedBox(height: 12),
              _SettingsCard(
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF9B59B6)]), shape: BoxShape.circle),
                    child: Center(child: Text(
                      (user.displayName?.isNotEmpty == true ? user.displayName![0] : user.email?[0] ?? '?').toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    )),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.displayName ?? 'Musician', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(user.email ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(_userRole == 'teacher' ? '👨‍🏫 Teacher' : '🎓 Student', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ])),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text('Sign Out', style: TextStyle(color: Color(0xFF9B59B6), fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
            ],

            // --- Profile ---
            _SectionHeader(label: 'Profile', icon: Icons.person_outline),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    labelStyle: const TextStyle(color: Colors.white60),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _purple)),
                    prefixIcon: const Icon(Icons.person, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Your Instrument(s)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white60)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _instruments.map((instrument) {
                    final isSelected = _selectedInstruments.contains(instrument);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            if (_selectedInstruments.length > 1) _selectedInstruments.remove(instrument);
                          } else {
                            _selectedInstruments.add(instrument);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: isSelected ? const LinearGradient(colors: [_purple, Color(0xFF9B59B6)]) : null,
                          color: isSelected ? null : Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? Colors.transparent : _purple.withOpacity(0.3)),
                          boxShadow: isSelected ? [BoxShadow(color: _purple.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))] : [],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (isSelected) ...[const Icon(Icons.check, size: 12, color: Colors.white), const SizedBox(width: 4)],
                          Text(instrument, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // --- Reminders ---
            _SectionHeader(label: 'Practice Reminders', icon: Icons.notifications_outlined),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _purple.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.notifications_outlined, color: _purple, size: 18)),
                    const SizedBox(width: 12),
                    const Text('Daily Reminder', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500)),
                  ]),
                  Switch(value: _reminderEnabled, onChanged: (val) => setState(() => _reminderEnabled = val), activeColor: _purple),
                ]),
                if (_reminderEnabled) ...[
                  const SizedBox(height: 12),
                  Divider(color: _purple.withOpacity(0.2)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.access_time, color: Colors.teal, size: 18)),
                      const SizedBox(width: 12),
                      const Text('Reminder Time', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500)),
                    ]),
                    GestureDetector(
                      onTap: _pickReminderTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF9B59B6)]), borderRadius: BorderRadius.circular(14)),
                        child: Text(_formatTime(_reminderTime), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withOpacity(0.2))),
                    child: const Row(children: [Icon(Icons.info_outline, size: 14, color: _purple), SizedBox(width: 8), Expanded(child: Text('Notification fires when the app is closed or in the background.', style: TextStyle(fontSize: 12, color: Color(0xFF9B59B6))))]),
                  ),
                ],
                Divider(color: _purple.withOpacity(0.2), height: 28),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.local_fire_department_outlined, color: Colors.orange, size: 18)),
                    const SizedBox(width: 12),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Streak Risk Reminder', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500)),
                      Text('8pm if you haven\'t practiced', style: TextStyle(fontSize: 11, color: Colors.white38)),
                    ]),
                  ]),
                  Switch(value: _streakReminderEnabled, onChanged: (val) => setState(() => _streakReminderEnabled = val), activeColor: _purple),
                ]),
              ]),
            ),
            const SizedBox(height: 24),

            // --- Sharing ---
            _SectionHeader(label: 'Sharing', icon: Icons.share_outlined),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF00BFA5).withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.share_outlined, color: Color(0xFF00BFA5), size: 18)),
                    const SizedBox(width: 12),
                    const Text('Ask to share after sessions', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500)),
                  ]),
                  Switch(value: _sharePromptEnabled, onChanged: (val) => setState(() => _sharePromptEnabled = val), activeColor: _purple),
                ]),
                if (!PurchaseService().isPro) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withOpacity(0.2))),
                    child: const Row(children: [Icon(Icons.lock_outline, size: 14, color: _purple), SizedBox(width: 8), Expanded(child: Text('Session sharing requires Zyntune Pro.', style: TextStyle(fontSize: 12, color: Color(0xFF9B59B6))))]),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 24),

            // --- Teacher / Student Section ---
            _SectionHeader(label: isStudent ? 'My Teacher' : 'Teacher Mode', icon: Icons.school_outlined),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (isStudent) ...[
                  if (isLinked) ...[
                    // Already linked
                    Row(children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.check_circle, color: Colors.green, size: 22)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Linked to $_linkedTeacherName', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        const Text('Your teacher can see your practice progress.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
                      ])),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkTeacherScreen())).then((_) => _loadUserRole()),
                        icon: const Icon(Icons.link_off, size: 18),
                        label: const Text('Change Teacher'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Not linked
                    Row(children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _purple.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.link, color: _purple, size: 22)),
                      const SizedBox(width: 14),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Link to Your Teacher', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('Enter your teacher\'s code to connect to their studio.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
                      ])),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkTeacherScreen())).then((_) => _loadUserRole()),
                        icon: const Icon(Icons.link, size: 18),
                        label: const Text('Link to Teacher\'s Studio'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  // Teacher view
                  Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]), borderRadius: BorderRadius.circular(12)), child: const Text('👨‍🏫', style: TextStyle(fontSize: 20))),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Teacher Studio', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('View your students and their practice progress in the Studio tab.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
                    ])),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.green.withOpacity(0.3))),
                    child: const Row(children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 10),
                      Expanded(child: Text('Teacher Studio is active — head to the Studio tab to manage your students.', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500))),
                    ]),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 24),

            // --- About ---
            _SectionHeader(label: 'About', icon: Icons.info_outline),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(children: [
                _AboutRow(icon: Icons.music_note, label: 'Zyntune', value: 'Version 2.3.0', color: _purple),
                Divider(color: _purple.withOpacity(0.2)),
                const _AboutRow(icon: Icons.code, label: 'Built with Flutter', value: '💙', color: Color(0xFF2196F3)),
              ]),
            ),
            const SizedBox(height: 28),

            // --- Save Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 4,
                  shadowColor: _purple.withOpacity(0.4),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Danger Zone ---
            Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.withOpacity(0.8), size: 18),
              const SizedBox(width: 8),
              Text('Danger Zone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.withOpacity(0.8))),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _resetAllData,
                icon: const Icon(Icons.delete_forever, size: 20),
                label: const Text('Reset All Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.12),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.red.withOpacity(0.5))),
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
  const _SectionHeader({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF6B21FF).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: const Color(0xFF6B21FF))),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
    ]);
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_cardBg, _cardBg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
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
  const _AboutRow({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500))),
        Text(value, style: const TextStyle(fontSize: 13, color: Colors.white54)),
      ]),
    );
  }
}