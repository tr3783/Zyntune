import 'package:flutter/material.dart';
import '../purchase_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _purchaseService = PurchaseService();
  String _selected = 'annual'; // 'annual', 'monthly', 'lifetime'

  static const _purple = Color(0xFF6B21FF);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _purchaseService,
      builder: (context, _) {
        final monthly = _purchaseService.monthlyProduct;
        final annual = _purchaseService.annualProduct;
        final lifetime = _purchaseService.lifetimeProduct;
        final pending = _purchaseService.purchasePending;

        final isLifetime = _selected == 'lifetime';

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D1A),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
            child: Column(
              children: [
                // --- Header ---
                const Text('⭐', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text('Zyntune Pro', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                const Text('Unlock the full practice experience', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 15)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isLifetime
                        ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)])
                        : const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF00897B)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isLifetime ? 'One-time payment — yours forever' : '7-day free trial — cancel anytime',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 32),

                // --- Features ---
                const _FeatureRow(emoji: '🎵', title: 'Metronome Subdivisions', subtitle: 'Eighth, Triplet and Sixteenth note subdivisions'),
                const SizedBox(height: 12),
                const _FeatureRow(emoji: '🧊', title: 'Streak Freeze', subtitle: 'Protect your streak on a missed day'),
                const SizedBox(height: 12),
                const _FeatureRow(emoji: '📅', title: 'Practice Calendar', subtitle: 'Schedule recitals, lessons and deadlines'),
                const SizedBox(height: 12),
                const _FeatureRow(emoji: '📊', title: 'Advanced Stats & Report Card', subtitle: 'Best day, best week, 6-month chart, weekly report'),
                const SizedBox(height: 12),
                const _FeatureRow(emoji: '📸', title: 'Shareable Session Cards', subtitle: 'Share your practice to iMessage, Instagram and more'),
                const SizedBox(height: 12),
                const _FeatureRow(emoji: '☁️', title: 'iCloud Sync', subtitle: 'Your data backed up and synced across devices'),
                const SizedBox(height: 12),
                const _FeatureRow(emoji: '🚀', title: 'All Future Features', subtitle: 'Every new Pro feature as Zyntune grows'),
                const SizedBox(height: 32),

                // --- Plan Selector ---
                if (annual != null) ...[
                  GestureDetector(
                    onTap: () => setState(() => _selected = 'annual'),
                    child: _PlanCard(
                      title: 'Annual',
                      price: annual.price,
                      subtitle: 'Best value — save over 40%',
                      badge: 'BEST VALUE',
                      isSelected: _selected == 'annual',
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (monthly != null) ...[
                  GestureDetector(
                    onTap: () => setState(() => _selected = 'monthly'),
                    child: _PlanCard(
                      title: 'Monthly',
                      price: monthly.price,
                      subtitle: 'Flexible — cancel anytime',
                      isSelected: _selected == 'monthly',
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (lifetime != null) ...[
                  GestureDetector(
                    onTap: () => setState(() => _selected = 'lifetime'),
                    child: _PlanCard(
                      title: 'Lifetime',
                      price: lifetime.price,
                      subtitle: 'One-time payment — never pay again',
                      badge: 'FOREVER',
                      isSelected: _selected == 'lifetime',
                      isLifetime: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                if (monthly == null && annual == null && lifetime == null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                    child: const Text('Loading subscription options...', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                  ),
                ],
                const SizedBox(height: 28),

                // --- CTA Button ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: pending ? null : () async {
                      if (_selected == 'annual' && annual != null) {
                        await _purchaseService.buyAnnual();
                      } else if (_selected == 'monthly' && monthly != null) {
                        await _purchaseService.buyMonthly();
                      } else if (_selected == 'lifetime' && lifetime != null) {
                        await _purchaseService.buyLifetime();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLifetime ? const Color(0xFFFFD700) : _purple,
                      foregroundColor: isLifetime ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: isLifetime ? const Color(0xFFFFD700).withOpacity(0.5) : _purple.withOpacity(0.5),
                    ),
                    child: pending
                        ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: isLifetime ? Colors.black : Colors.white, strokeWidth: 2))
                        : Text(
                            isLifetime ? 'Get Lifetime Access' : 'Start Free Trial',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                if (_purchaseService.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_purchaseService.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),

                TextButton(
                  onPressed: () => _purchaseService.restorePurchases(),
                  child: const Text('Restore Purchases', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ),

                const SizedBox(height: 8),
                Text(
                  isLifetime
                      ? 'One-time payment. No subscription. Pro access forever including all future features.'
                      : 'Payment will be charged to your Apple ID account. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. You can manage or cancel your subscription in your App Store account settings.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white24, fontSize: 10, height: 1.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const _FeatureRow({required this.emoji, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: const Color(0xFF6B21FF).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
        const Icon(Icons.check_circle, color: Color(0xFF00BFA5), size: 20),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final String? badge;
  final bool isSelected;
  final bool isLifetime;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.subtitle,
    this.badge,
    required this.isSelected,
    this.isLifetime = false,
  });

  static const _purple = Color(0xFF6B21FF);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  @override
  Widget build(BuildContext context) {
    final selectedGradient = isLifetime
        ? const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFFFD700)], begin: Alignment.topLeft, end: Alignment.bottomRight)
        : const LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isSelected ? selectedGradient : const LinearGradient(colors: [_cardBg, _cardBg2]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? Colors.transparent : isLifetime ? const Color(0xFFFFD700).withOpacity(0.3) : Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: isLifetime ? const Color(0xFFFFD700).withOpacity(0.3) : _purple.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
            : [],
      ),
      child: Row(
        children: [
          Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? Colors.white : Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 15, fontWeight: FontWeight.bold)),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLifetime ? const Color(0xFFFFD700) : const Color(0xFF00BFA5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge!, style: TextStyle(color: isLifetime ? Colors.black : Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                ],
              ]),
              Text(subtitle, style: TextStyle(color: isSelected ? Colors.white70 : Colors.white38, fontSize: 12)),
            ]),
          ),
          Text(price, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}