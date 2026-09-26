import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../notification_helper.dart';
import '../streak_helper.dart';
import '../purchase_service.dart';
import '../auth_service.dart';
import '../icloud_sync_service.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _parentEmailController = TextEditingController();

  bool _reminderEnabled = false;
  bool _streakReminderEnabled = true;
  bool _sharePromptEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  static const List<String> _instruments = [
    'Guitar', 'Bass', 'Piano', 'Violin', 'Viola', 'Cello',
    'Drums', 'Voice', 'Trumpet', 'Flute', 'Saxophone', 'Clarinet', 'Other',
  ];
  List<String> _selectedInstruments = ['Guitar'];

  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final reminderSettings = await NotificationHelper.getReminderSettings();
    final instrumentsList = prefs.getStringList('instruments');
    final legacyInstrument = prefs.getString('instrument') ?? 'Guitar';

    setState(() {
      _nameController.text = prefs.getString('userName') ?? 'Musician';
      _parentEmailController.text = prefs.getString('parentEmail') ?? '';
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

    // Save parent email
    final parentEmail = _parentEmailController.text.trim();
    await prefs.setString('parentEmail', parentEmail);
    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'parentEmail': parentEmail,
      });
    }

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

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
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
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Sign Out')),
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

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently delete your account and all your data. This cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Delete Forever')),
        ],
      ),
    );
    if (confirm == true) await AuthService().deleteAccount();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final isPro = PurchaseService().isPro;

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Account Card ---
            if (user != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: _purple.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: Center(child: Text(
                      (user.displayName?.isNotEmpty == true ? user.displayName![0] : user.email?[0] ?? '?').toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    )),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.displayName ?? 'Musician', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(user.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: isPro ? Colors.amber.withOpacity(0.3) : Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text(isPro ? '⭐ Pro' : 'Free', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ])),
                  if (!isPro)
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Upgrade', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 24),

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
                TextField(
                  controller: _parentEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Parent / Guardian Email (optional)',
                    labelStyle: const TextStyle(color: Colors.white60),
                    hintText: 'parent@example.com',
                    hintStyle: const TextStyle(color: Colors.white30),
                    helperText: 'They\'ll receive a copy of teacher reminders and assignments',
                    helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _purple)),
                    prefixIcon: const Icon(Icons.family_restroom, color: Colors.white54),
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
                        child: Text(instrument, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      ),
                    );
                  }).toList(),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // --- Notifications ---
            _SectionHeader(label: 'Notifications', icon: Icons.notifications_outlined),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.alarm, color: Color(0xFF00BFA5), size: 20),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Daily Practice Reminder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Get a reminder to practice each day', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ])),
                  Switch(
                    value: _reminderEnabled,
                    onChanged: (val) => setState(() => _reminderEnabled = val),
                    activeColor: _purple,
                  ),
                ]),
                if (_reminderEnabled) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: _purple.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple.withOpacity(0.3))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Reminder Time', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        Text(_formatTime(_reminderTime), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ]),
                    ),
                  ),
                ],
                const Divider(color: Colors.white12, height: 24),
                Row(children: [
                  const Icon(Icons.local_fire_department, color: Color(0xFFFF6B35), size: 20),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Streak Risk Reminder', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Remind me at 8 PM if I haven\'t practiced', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ])),
                  Switch(
                    value: _streakReminderEnabled,
                    onChanged: (val) async {
                      setState(() => _streakReminderEnabled = val);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('streakReminderEnabled', val);
                      if (val) {
                        final streakData = await StreakHelper.getStreakData();
                        await NotificationHelper.scheduleStreakRiskReminder(
                          currentStreak: streakData['currentStreak'] ?? 0,
                        );
                      } else {
                        await NotificationHelper.cancelStreakRiskReminder();
                      }
                    },
                    activeColor: _purple,
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 24),

            // --- Preferences ---
            _SectionHeader(label: 'Preferences', icon: Icons.tune),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Row(children: [
                const Icon(Icons.share, color: Color(0xFF2196F3), size: 20),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Session Share Prompt', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('Ask to share after saving a session', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ])),
                Switch(
                  value: _sharePromptEnabled,
                  onChanged: (val) => setState(() => _sharePromptEnabled = val),
                  activeColor: _purple,
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // --- Account Actions ---
            _SectionHeader(label: 'Account', icon: Icons.manage_accounts_outlined),
            const SizedBox(height: 12),
            _SettingsCard(
              child: Column(children: [
                _ActionRow(icon: Icons.logout, label: 'Sign Out', color: Colors.orange, onTap: _signOut),
                const Divider(color: Colors.white12, height: 20),
                _ActionRow(icon: Icons.delete_forever, label: 'Delete Account', color: Colors.red, onTap: _deleteAccount),
              ]),
            ),
            const SizedBox(height: 32),

            Center(
              child: Text(
                'Zyntune • Music Practice App',
                style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
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
      Icon(icon, color: const Color(0xFF9B59B6), size: 18),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
    ]);
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A0A4E), Color(0xFF2D1B69)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6B21FF).withOpacity(0.3)),
      ),
      child: child,
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        const Spacer(),
        Icon(Icons.chevron_right, color: color.withOpacity(0.5), size: 18),
      ]),
    );
  }
}