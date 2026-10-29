import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../help_content.dart';
import 'tool_intro.dart';

/// Help & FAQ (Settings). Questions grouped by topic, plus each tool's intro.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _purple = Color(0xFF6B21FF);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _pink = Color(0xFFE91E8C);

  static const _tools = ['home', 'metronome', 'timer', 'record', 'repertoire', 'goals', 'stats', 'tuner', 'notes', 'calendar'];

  Future<void> _email(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: supportEmail, query: 'subject=Zyntune%20Help');
    if (!await launchUrl(uri) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email us at $supportEmail')));
    }
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text, style: const TextStyle(color: _pink, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text('Help & FAQ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          for (final section in faqSections) ...[
            _sectionTitle(section.title.toUpperCase()),
            Container(
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16)),
              child: Theme(
                // No divider lines between the expanding rows.
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Column(children: [
                  for (final item in section.items)
                    ExpansionTile(
                      iconColor: Colors.white70,
                      collapsedIconColor: Colors.white38,
                      title: Text(item.question, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(item.answer, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.45))],
                    ),
                ]),
              ),
            ),
          ],
          _sectionTitle('HOW EACH TOOL WORKS'),
          Container(
            decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              for (final tool in _tools)
                ListTile(
                  title: Text(toolIntros[tool]!.title, style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () => showToolIntro(context, tool),
                ),
            ]),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _email(context),
            icon: const Icon(Icons.mail_outline),
            label: const Text('Still need help? Email us'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(supportEmail, textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}
