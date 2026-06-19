import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'paywall_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customGoalController = TextEditingController();
  final TextEditingController _otherInstrumentController = TextEditingController();
  List<String> _selectedInstruments = ['Guitar'];
  int _dailyGoalMinutes = 20;

  static const _purple = Color(0xFF6B21FF);

  final List<String> _instruments = [
    'Guitar', 'Piano', 'Violin', 'Viola', 'Cello',
    'Bass', 'Drums', 'Voice', 'Trumpet', 'Flute',
    'Saxophone', 'Clarinet', 'Other',
  ];

  final List<int> _goalOptions = [10, 15, 20, 30, 45, 60];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _customGoalController.dispose();
    _otherInstrumentController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  Future<void> _completeOnboarding() async {
    if (_selectedInstruments.isEmpty) _selectedInstruments = ['Guitar'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    await prefs.setString('userName', _nameController.text.trim().isEmpty ? 'Musician' : _nameController.text.trim());
    await prefs.setStringList('instruments', _selectedInstruments);
    await prefs.setString('activeInstrument', _selectedInstruments.first);
    await prefs.setString('instrument', _selectedInstruments.first);
    await prefs.setInt('dailyGoalMinutes', _dailyGoalMinutes);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  List<List<Color>> get _gradients => [
    const [Color(0xFF6B21FF), Color(0xFF9B59B6)],
    const [Color(0xFF00695C), Color(0xFF00BFA5)],
    const [Color(0xFFE65100), Color(0xFFFF6B35)],
    const [Color(0xFF1565C0), Color(0xFF42A5F5)],
    const [Color(0xFF6B21FF), Color(0xFF9B59B6)],
  ];

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[_currentPage];
    final pageColor = gradient[0];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradient[0].withOpacity(0.15), const Color(0xFF0D0D1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), shape: BoxShape.circle),
                        child: const Icon(Icons.music_note, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text('Zyntune', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1)),
                    ]),
                    if (_currentPage < 4)
                      GestureDetector(
                        onTap: () => _pageController.animateToPage(4, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: const Text('Skip', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                      )
                    else
                      const SizedBox(width: 60),
                  ],
                ),
              ),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: [
                    _buildWelcomePage(),
                    _buildTimerPage(),
                    _buildStreakPage(),
                    _buildProPage(),
                    _buildSetupPage(),
                  ],
                ),
              ),

              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: _currentPage == index ? LinearGradient(colors: gradient) : null,
                    color: _currentPage == index ? null : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
              const SizedBox(height: 20),

              // Navigation
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _currentPage > 0
                        ? GestureDetector(
                            onTap: _previousPage,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.2))),
                              child: const Row(children: [
                                Icon(Icons.arrow_back, color: Colors.white70, size: 18),
                                SizedBox(width: 6),
                                Text('Back', style: TextStyle(color: Colors.white70, fontSize: 15)),
                              ]),
                            ),
                          )
                        : const SizedBox(width: 80),
                    GestureDetector(
                      onTap: _currentPage == 4 ? _completeOnboarding : _nextPage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradient),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [BoxShadow(color: pageColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Row(children: [
                          Text(_currentPage == 4 ? 'Get Started!' : 'Next', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Icon(_currentPage == 4 ? Icons.check_rounded : Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Page 1: Welcome ---
  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        const SizedBox(height: 24),
        _buildEmojiCircle('🎵', _gradients[0]),
        const SizedBox(height: 32),
        _buildGradientTitle('Welcome to Zyntune', _gradients[0]),
        const SizedBox(height: 16),
        const Text('Your personal music practice companion. Practice smarter, stay consistent, and grow faster.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white60, height: 1.6)),
        const SizedBox(height: 32),
        _buildFeaturePill(Icons.timer_outlined, 'Practice Timer', 'Stopwatch & countdown', const Color(0xFF00BFA5)),
        const SizedBox(height: 10),
        _buildFeaturePill(Icons.local_fire_department_outlined, 'Streak Tracking', 'Build daily consistency', const Color(0xFFFF6B35)),
        const SizedBox(height: 10),
        _buildFeaturePill(Icons.library_music_outlined, 'Repertoire', 'Manage your pieces', const Color(0xFFE91E8C)),
        const SizedBox(height: 10),
        _buildFeaturePill(Icons.bar_chart, 'Stats & Goals', 'See your progress', const Color(0xFF2196F3)),
        const SizedBox(height: 24),
      ]),
    );
  }

  // --- Page 2: Timer & Practice ---
  Widget _buildTimerPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        const SizedBox(height: 24),
        _buildEmojiCircle('⏱️', _gradients[1]),
        const SizedBox(height: 32),
        _buildGradientTitle('Track Every Session', _gradients[1]),
        const SizedBox(height: 16),
        const Text('Log your practice with a stopwatch or set a countdown timer. Every minute counts.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white60, height: 1.6)),
        const SizedBox(height: 32),
        _buildInfoCard('⏱', 'Stopwatch Mode', 'Start when you begin, stop when you\'re done. Add notes and tag the piece you worked on.', const Color(0xFF00695C)),
        const SizedBox(height: 12),
        _buildInfoCard('⏳', 'Countdown Mode', 'Set a target time and practice until the timer runs out. Even works in the background.', const Color(0xFF00BFA5)),
        const SizedBox(height: 12),
        _buildInfoCard('📊', 'Session History', 'All your sessions are saved. Edit, delete, or review anytime.', const Color(0xFF4CAF50)),
        const SizedBox(height: 24),
      ]),
    );
  }

  // --- Page 3: Streaks & Goals ---
  Widget _buildStreakPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        const SizedBox(height: 24),
        _buildEmojiCircle('🔥', _gradients[2]),
        const SizedBox(height: 32),
        _buildGradientTitle('Stay Motivated', _gradients[2]),
        const SizedBox(height: 16),
        const Text('Consistency beats talent. Zyntune helps you build and protect your daily practice habit.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white60, height: 1.6)),
        const SizedBox(height: 32),
        _buildInfoCard('🔥', 'Daily Streaks', 'Practice every day to build your streak. Miss a day and it resets — stay consistent!', const Color(0xFFE65100)),
        const SizedBox(height: 12),
        _buildInfoCard('🎯', 'Daily Goals', 'Set a daily practice target. The home screen tracks your progress in real time.', const Color(0xFFFF6B35)),
        const SizedBox(height: 12),
        _buildInfoCard('🏆', 'Achievements', 'Unlock badges for milestones — first session, 7-day streak, 10 hours practiced and more.', const Color(0xFFFFB300)),
        const SizedBox(height: 24),
      ]),
    );
  }

  // --- Page 4: Pro Teaser ---
  Widget _buildProPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        const SizedBox(height: 24),
        _buildEmojiCircle('⭐', _gradients[3]),
        const SizedBox(height: 32),
        _buildGradientTitle('Go Further with Pro', _gradients[3]),
        const SizedBox(height: 16),
        const Text('Zyntune is free to use. Serious musicians can unlock Pro for advanced tools.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white60, height: 1.6)),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_gradients[3][0].withOpacity(0.2), _gradients[3][1].withOpacity(0.1)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _gradients[3][0].withOpacity(0.4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Zyntune Pro includes:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 14),
            _buildProFeatureRow('🎵', 'Metronome subdivisions (Eighth, Triplet, Sixteenth)'),
            _buildProFeatureRow('🧊', 'Streak freeze — protect your streak on a missed day'),
            _buildProFeatureRow('📅', 'Practice calendar with events and deadlines'),
            _buildProFeatureRow('📊', 'Weekly report card and advanced stats'),
            _buildProFeatureRow('📸', 'Shareable session cards'),
            _buildProFeatureRow('☁️', 'iCloud sync across devices'),
            const SizedBox(height: 16),
            const Text('\$2.99/month or \$19.99/year', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('7-day free trial — cancel anytime', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _gradients[3]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: _gradients[3][0].withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Center(child: Text('Start Free Trial', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Or skip and use the free version', style: TextStyle(color: Colors.white30, fontSize: 12)),
        const SizedBox(height: 24),
      ]),
    );
  }

  // --- Page 5: Setup ---
  Widget _buildSetupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildEmojiCircle('🚀', _gradients[4]),
          const SizedBox(height: 32),
          _buildGradientTitle('Almost There!', _gradients[4]),
          const SizedBox(height: 8),
          const Text('Tell us a little about yourself to personalize your experience.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white60, height: 1.6)),
          const SizedBox(height: 28),

          // Name
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Your Name',
              labelStyle: const TextStyle(color: Colors.white60),
              hintText: 'e.g. Alex',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.person, color: Colors.white54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _purple)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 20),

          // Instrument
          const Text('Your Instrument(s)', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _instruments.map((instrument) {
              final isOther = instrument == 'Other';
              final isSelected = isOther
                  ? _selectedInstruments.any((i) => !_instruments.contains(i) || i == 'Other')
                  : _selectedInstruments.contains(instrument);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isOther) {
                      final hasOther = _selectedInstruments.any((i) => !_instruments.contains(i) || i == 'Other');
                      if (hasOther) {
                        _selectedInstruments.removeWhere((i) => !_instruments.contains(i) || i == 'Other');
                        _otherInstrumentController.clear();
                      } else {
                        _selectedInstruments.add('Other');
                      }
                    } else {
                      if (isSelected) {
                        if (_selectedInstruments.length > 1) _selectedInstruments.remove(instrument);
                      } else {
                        _selectedInstruments.add(instrument);
                      }
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? const LinearGradient(colors: [_purple, Color(0xFF9B59B6)]) : null,
                    color: isSelected ? null : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? Colors.transparent : _purple.withOpacity(0.3)),
                    boxShadow: isSelected ? [BoxShadow(color: _purple.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isSelected) ...[const Icon(Icons.check, size: 13, color: Colors.white), const SizedBox(width: 4)],
                    Text(instrument, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  ]),
                ),
              );
            }).toList(),
          ),
          // Show text field when Other is selected
          if (_selectedInstruments.contains('Other') || _selectedInstruments.any((i) => !_instruments.contains(i))) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _otherInstrumentController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'What instrument do you play?',
                labelStyle: const TextStyle(color: Colors.white60),
                hintText: 'e.g. Harp, Mandolin, Ukulele...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.music_note, color: Colors.white54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _purple)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              onChanged: (val) {
                setState(() {
                  _selectedInstruments.removeWhere((i) => !_instruments.contains(i) || i == 'Other');
                  if (val.trim().isNotEmpty) {
                    _selectedInstruments.add(val.trim());
                  } else {
                    _selectedInstruments.add('Other');
                  }
                });
              },
              textInputAction: TextInputAction.done,
            ),
          ],
          const SizedBox(height: 20),

          // Daily goal
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Daily Practice Goal', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
            GestureDetector(
              onTap: () => setState(() { _dailyGoalMinutes = 0; _customGoalController.clear(); }),
              child: Text(
                _dailyGoalMinutes == 0 ? 'Skipped' : 'Skip for now',
                style: TextStyle(color: _dailyGoalMinutes == 0 ? Colors.white38 : _purple.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _goalOptions.map((mins) {
              final isSelected = _dailyGoalMinutes == mins;
              return GestureDetector(
                onTap: () => setState(() { _dailyGoalMinutes = mins; _customGoalController.clear(); }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? const LinearGradient(colors: [_purple, Color(0xFF9B59B6)]) : null,
                    color: isSelected ? null : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? Colors.transparent : _purple.withOpacity(0.3)),
                    boxShadow: isSelected ? [BoxShadow(color: _purple.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                  ),
                  child: Text('$mins min', style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Custom: ', style: TextStyle(color: Colors.white60, fontSize: 13)),
            SizedBox(
              width: 70,
              child: TextField(
                controller: _customGoalController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'min',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _purple)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
                onChanged: (val) {
                  final mins = int.tryParse(val);
                  if (mins != null && mins > 0) setState(() => _dailyGoalMinutes = mins);
                },
                onSubmitted: (val) {
                  final mins = int.tryParse(val);
                  if (mins != null && mins > 0) setState(() => _dailyGoalMinutes = mins);
                  FocusScope.of(context).unfocus();
                },
              ),
            ),
            const Text(' minutes', style: TextStyle(color: Colors.white60, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          if (_dailyGoalMinutes > 0)
            Text('Goal set: $_dailyGoalMinutes min/day ✓', style: const TextStyle(color: Color(0xFF9B59B6), fontSize: 12, fontWeight: FontWeight.w600))
          else
            const Text('No goal set — you can always add one in Settings.', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- Helpers ---
  Widget _buildEmojiCircle(String emoji, List<Color> gradient) {
    return Container(
      width: 120, height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [gradient[0].withOpacity(0.3), gradient[1].withOpacity(0.1)]),
        border: Border.all(color: gradient[0].withOpacity(0.5), width: 2),
        boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 24, spreadRadius: 4)],
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 52))),
    );
  }

  Widget _buildGradientTitle(String title, List<Color> gradient) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        foreground: Paint()..shader = LinearGradient(colors: gradient).createShader(const Rect.fromLTWH(0, 0, 300, 50)),
        height: 1.2,
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String title, String subtitle, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.25))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _buildInfoCard(String emoji, String title, String body, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
        ])),
      ]),
    );
  }

  Widget _buildProFeatureRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
      ]),
    );
  }
}