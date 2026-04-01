import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final TextEditingController _nameController = TextEditingController();
  String _selectedInstrument = 'Guitar';

  final List<String> _instruments = [
    'Guitar', 'Piano', 'Violin', 'Viola', 'Cello',
    'Bass', 'Drums', 'Voice', 'Trumpet', 'Flute',
    'Saxophone', 'Clarinet', 'Other',
  ];

  final List<_OnboardingPage> _pages = [
    const _OnboardingPage(
      emoji: '🎵',
      title: 'Welcome to\nPractice Pilot',
      subtitle:
          'Your personal music practice assistant. Track sessions, set goals, and grow as a musician.',
      color: Colors.deepPurple,
    ),
    const _OnboardingPage(
      emoji: '⏱️',
      title: 'Track Your\nPractice Time',
      subtitle:
          'Use the stopwatch or countdown timer to log every session. Build consistency and watch your hours grow.',
      color: Colors.teal,
    ),
    const _OnboardingPage(
      emoji: '🎯',
      title: 'Set Goals &\nStay Motivated',
      subtitle:
          'Set daily practice goals, track your streak, and celebrate your progress with detailed stats.',
      color: Colors.orange,
    ),
    const _OnboardingPage(
      emoji: '🎼',
      title: 'Manage Your\nRepertoire',
      subtitle:
          'Keep track of every piece you\'re learning, in progress, or have mastered. Add notes and links.',
      color: Colors.pink,
    ),
    const _OnboardingPage(
      emoji: '🚀',
      title: 'Let\'s Get\nStarted!',
      subtitle: 'Tell us a little about yourself.',
      color: Colors.indigo,
      isLastPage: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    await prefs.setString(
        'userName', _nameController.text.trim().isEmpty
            ? 'Musician'
            : _nameController.text.trim());
    await prefs.setString('instrument', _selectedInstrument);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- Page View ---
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) =>
                setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _buildPage(page, index);
            },
          ),

          // --- Skip button (top right) ---
          if (_currentPage < _pages.length - 1)
            Positioned(
              top: 56,
              right: 24,
              child: TextButton(
                onPressed: () {
                  _pageController.animateToPage(
                    _pages.length - 1,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: _pages[_currentPage]
                        .color
                        .withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ),
            ),

          // --- Bottom navigation ---
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // Page dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin:
                          const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? _pages[_currentPage].color
                            : _pages[_currentPage]
                                .color
                                .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Navigation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    _currentPage > 0
                        ? OutlinedButton.icon(
                            onPressed: _previousPage,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(30)),
                            ),
                          )
                        : const SizedBox(width: 100),

                    // Next / Get Started button
                    ElevatedButton.icon(
                      onPressed: _currentPage == _pages.length - 1
                          ? _completeOnboarding
                          : _nextPage,
                      icon: Icon(
                        _currentPage == _pages.length - 1
                            ? Icons.check
                            : Icons.arrow_forward,
                      ),
                      label: Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started!'
                            : 'Next',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _pages[_currentPage].color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),

          // Emoji icon in colored circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: page.color.withOpacity(0.3), width: 2),
            ),
            child: Center(
              child: Text(
                page.emoji,
                style: const TextStyle(fontSize: 56),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: page.color,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Last page — name & instrument input
          if (page.isLastPage) ...[
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
                hintText: 'e.g. Alex',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.05),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedInstrument,
              decoration: InputDecoration(
                labelText: 'Your Instrument',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.music_note),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.05),
              ),
              items: _instruments
                  .map((i) => DropdownMenuItem(
                        value: i,
                        child: Text(i),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedInstrument = val);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

// Data class for each onboarding page
class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLastPage;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isLastPage = false,
  });
}