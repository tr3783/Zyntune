import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() =>
      _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final TextEditingController _nameController =
      TextEditingController();
  String _selectedInstrument = 'Guitar';

  static const _purple = Color(0xFF6B21FF);

  final List<String> _instruments = [
    'Guitar', 'Piano', 'Violin', 'Viola', 'Cello',
    'Bass', 'Drums', 'Voice', 'Trumpet', 'Flute',
    'Saxophone', 'Clarinet', 'Other',
  ];

  final List<_OnboardingPage> _pages = [
    const _OnboardingPage(
      emoji: '🎵',
      title: 'Welcome to Zyntune',
      subtitle:
          'Your personal music practice assistant. Track sessions, set goals, and grow as a musician.',
      gradient: [Color(0xFF6B21FF), Color(0xFF9B59B6)],
    ),
    const _OnboardingPage(
      emoji: '⏱️',
      title: 'Track Your Practice',
      subtitle:
          'Use the stopwatch or countdown timer to log every session. Build consistency and watch your hours grow.',
      gradient: [Color(0xFF00695C), Color(0xFF00BFA5)],
    ),
    const _OnboardingPage(
      emoji: '🎯',
      title: 'Set Goals & Stay Motivated',
      subtitle:
          'Set daily practice goals, track your streak, and celebrate your progress with detailed stats.',
      gradient: [Color(0xFFE65100), Color(0xFFFF6B35)],
    ),
    const _OnboardingPage(
      emoji: '🎼',
      title: 'Manage Your Repertoire',
      subtitle:
          'Keep track of every piece you\'re learning, working on, or performance ready.',
      gradient: [Color(0xFFAD1457), Color(0xFFE91E8C)],
    ),
    const _OnboardingPage(
      emoji: '🚀',
      title: 'Let\'s Get Started!',
      subtitle: 'Tell us a little about yourself so we can personalize your experience.',
      gradient: [Color(0xFF6B21FF), Color(0xFF9B59B6)],
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
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    await prefs.setString(
        'userName',
        _nameController.text.trim().isEmpty
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
    final page = _pages[_currentPage];
    final pageColor = page.gradient[0];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              page.gradient[0].withOpacity(0.15),
              const Color(0xFF0D0D1A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [

              // Top bar with skip
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: page.gradient),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.music_note,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Zyntune',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    if (_currentPage < _pages.length - 1)
                      GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            _pages.length - 1,
                            duration: const Duration(
                                milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 60),
                  ],
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),

              // Page dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 4),
                    width: _currentPage == index ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: _currentPage == index
                          ? LinearGradient(
                              colors: _pages[_currentPage]
                                  .gradient)
                          : null,
                      color: _currentPage == index
                          ? null
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Navigation buttons
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    _currentPage > 0
                        ? GestureDetector(
                            onTap: _previousPage,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(
                                        30),
                                border: Border.all(
                                    color: Colors.white
                                        .withOpacity(0.2)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.arrow_back,
                                      color: Colors.white70,
                                      size: 18),
                                  SizedBox(width: 6),
                                  Text('Back',
                                      style: TextStyle(
                                          color:
                                              Colors.white70,
                                          fontSize: 15)),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox(width: 80),
                    GestureDetector(
                      onTap:
                          _currentPage == _pages.length - 1
                              ? _completeOnboarding
                              : _nextPage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: page.gradient),
                          borderRadius:
                              BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: pageColor
                                  .withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              _currentPage ==
                                      _pages.length - 1
                                  ? 'Get Started!'
                                  : 'Next',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage ==
                                      _pages.length - 1
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
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

  Widget _buildPage(_OnboardingPage page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          // Emoji icon with gradient ring
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  page.gradient[0].withOpacity(0.3),
                  page.gradient[1].withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: page.gradient[0].withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: page.gradient[0].withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                page.emoji,
                style: const TextStyle(fontSize: 58),
              ),
            ),
          ),
          const SizedBox(height: 36),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: page.gradient,
                ).createShader(
                    const Rect.fromLTWH(0, 0, 300, 50)),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white60,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),

          // Last page inputs
          if (page.isLastPage) ...[
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Your Name',
                labelStyle:
                    const TextStyle(color: Colors.white60),
                hintText: 'e.g. Alex',
                hintStyle:
                    const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.person,
                    color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: _purple.withOpacity(0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: _purple.withOpacity(0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: _purple),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedInstrument,
              dropdownColor: const Color(0xFF1A0A4E),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Your Instrument',
                labelStyle:
                    const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.music_note,
                    color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: _purple.withOpacity(0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: _purple.withOpacity(0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: _purple),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
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
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final bool isLastPage;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    this.isLastPage = false,
  });
}