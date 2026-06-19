import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth_service.dart';

class LinkTeacherScreen extends StatefulWidget {
  const LinkTeacherScreen({super.key});

  @override
  State<LinkTeacherScreen> createState() => _LinkTeacherScreenState();
}

class _LinkTeacherScreenState extends State<LinkTeacherScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _linkedTeacherName;

  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  @override
  void initState() {
    super.initState();
    _loadLinkedTeacher();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedTeacher() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final teacherId = doc.data()?['teacherId'] as String?;
    if (teacherId != null) {
      final teacherDoc = await FirebaseFirestore.instance.collection('users').doc(teacherId).get();
      setState(() => _linkedTeacherName = teacherDoc.data()?['name'] as String? ?? 'Your Teacher');
    }
  }

  Future<void> _linkTeacher() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Please enter a valid 6-character code.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final db = FirebaseFirestore.instance;
      final uid = AuthService().currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      // Find teacher with this code
      final query = await db.collection('users')
          .where('teacherCode', isEqualTo: code)
          .where('role', isEqualTo: 'teacher')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _error = 'No teacher found with that code. Check and try again.');
        return;
      }

      final teacher = query.docs.first;
      final teacherId = teacher.id;
      final teacherName = teacher.data()['name'] as String? ?? 'Your Teacher';

      // Link student to teacher
      await db.collection('users').doc(uid).update({'teacherId': teacherId});

      setState(() => _linkedTeacherName = teacherName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Linked to $teacherName\'s studio!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlinkTeacher() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Unlink Teacher', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to unlink from your teacher\'s studio?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Unlink')),
        ],
      ),
    );

    if (confirm == true) {
      final uid = AuthService().currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({'teacherId': FieldValue.delete()});
        setState(() => _linkedTeacherName = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text('Link to Teacher', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_linkedTeacherName != null) ...[
              // Already linked
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.withOpacity(0.15), Colors.green.withOpacity(0.08)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: Column(children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 40),
                  const SizedBox(height: 12),
                  Text('Linked to $_linkedTeacherName\'s Studio', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Your teacher can see your practice sessions, streak and progress.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _unlinkTeacher, child: const Text('Unlink from studio', style: TextStyle(color: Colors.red, fontSize: 13))),
                ]),
              ),
            ] else ...[
              // Not linked
              const Text('👨‍🏫', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Join Your Teacher\'s Studio', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Ask your teacher for their 6-character code and enter it below.', style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
              const SizedBox(height: 32),

              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 8, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: '------',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 28, letterSpacing: 8),
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _purple, width: 2)),
                  filled: true,
                  fillColor: const Color(0xFF1A0A4E),
                ),
              ),
              const SizedBox(height: 16),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _linkTeacher,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Join Studio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}