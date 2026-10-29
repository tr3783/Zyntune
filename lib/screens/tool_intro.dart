import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../help_content.dart';

/// An ⓘ button for a tool's app bar. It shows the tool's intro card the
/// first time the tool is opened (unless [autoShow] is false), and again
/// whenever it's tapped.
class ToolIntroButton extends StatefulWidget {
  final String tool;
  final bool autoShow;
  const ToolIntroButton(this.tool, {super.key, this.autoShow = true});

  @override
  State<ToolIntroButton> createState() => _ToolIntroButtonState();
}

class _ToolIntroButtonState extends State<ToolIntroButton> {
  @override
  void initState() {
    super.initState();
    if (widget.autoShow) WidgetsBinding.instance.addPostFrameCallback((_) => _showOnce());
  }

  Future<void> _showOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'toolIntroSeen_${widget.tool}';
      if (prefs.getBool(key) ?? false) return;
      await prefs.setBool(key, true);
      // Let the screen finish opening first.
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) await showToolIntro(context, widget.tool);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'How it works',
      icon: const Icon(Icons.info_outline, color: Colors.white),
      onPressed: () => showToolIntro(context, widget.tool),
    );
  }
}

Future<void> showToolIntro(BuildContext context, String tool) async {
  final intro = toolIntros[tool];
  if (intro == null) return;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A0A4E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(intro.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: intro.points
              .map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 7, right: 10),
                        child: Icon(Icons.circle, size: 6, color: Color(0xFFE91E8C)),
                      ),
                      Expanded(child: Text(p, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4))),
                    ]),
                  ))
              .toList(),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B21FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );
}
