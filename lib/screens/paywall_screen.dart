import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/packs_provider.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../utils/constants.dart';
import '../services/purchase_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _loading = false;
  int _selectedPlan = 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logPaywallView('paywall_screen');
  }

  List<_Plan> get _plans {
    final products = PurchaseService.instance.products;
    if (products.isEmpty) {
      return [
        const _Plan('Річна', '449 грн', '/рік', 'Найвигідніше'),
        const _Plan('Місячна', '79 грн', '/місяць', null),
      ];
    }
    return products.map((p) {
      final isYearly = p.id == 'yearly_premium';
      return _Plan(
        isYearly ? 'Річна' : 'Місячна',
        p.price,
        isYearly ? '/рік' : '/місяць',
        isYearly ? 'Найвигідніше' : null,
      );
    }).toList();
  }

  Future<void> _purchase() async {
    final productId = _selectedPlan == 0 ? 'yearly_premium' : 'monthly_premium';
    AnalyticsService.instance.logPurchaseStart(productId);
    setState(() => _loading = true);
    final success = await PurchaseService.instance.purchase(planIndex: _selectedPlan);
    if (!mounted) return;
    if (!success) {
      setState(() => _loading = false);
      return;
    }
    // Wait for purchase stream to update isPro
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _loading = false);

    if (PurchaseService.instance.isPro.value) {
      AnalyticsService.instance.logPurchaseSuccess(productId);
      ref.read(isProProvider.notifier).state = true;
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _restore() async {
    AnalyticsService.instance.logPurchaseRestore();
    setState(() => _loading = true);
    final restored = await PurchaseService.instance.restore();
    if (!mounted) return;
    setState(() => _loading = false);

    if (restored) {
      ref.read(isProProvider.notifier).state = true;
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Підписку не знайдено')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(Icons.close, color: Colors.grey[400], size: 28),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Text('🌟', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 16),
                    Text(
                      RemoteConfigService.instance.paywallTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.headlineSmall?.color,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _benefit('✓  6 розділів для розвитку'),
                    const SizedBox(height: 8),
                    _benefit('✓  174 яскраві картки зі звуком'),
                    const SizedBox(height: 8),
                    _benefit('✓  Нові розділи щомісяця'),
                    const SizedBox(height: 8),
                    _benefit('✓  3 дні безкоштовно'),
                    const SizedBox(height: 28),
                    ...List.generate(plans.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _planTile(i, plans),
                      );
                    }),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _purchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 4,
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                RemoteConfigService.instance.paywallCta,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '3 дні безкоштовно, потім ${plans[_selectedPlan].price}${plans[_selectedPlan].period}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _loading ? null : _restore,
                      child: Text(
                        'Відновити покупки',
                        style: TextStyle(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _legalLink('Умови використання', 'https://aihnatiev1.github.io/talking-cards/terms.html'),
                          _legalLink('EULA', 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                          _legalLink('Конфіденційність', 'https://aihnatiev1.github.io/talking-cards/privacy-policy.html'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legalLink(String title, String url) {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[500],
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _planTile(int index, List<_Plan> plans) {
    final plan = plans[index];
    final selected = _selectedPlan == index;
    const accent = kAccent;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : Colors.grey.shade300,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? accent : Colors.grey.shade400,
                  width: 2,
                ),
                color: selected ? accent : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: selected ? accent : null,
                        ),
                      ),
                      if (plan.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            plan.badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${plan.price}${plan.period}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: selected ? accent : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefit(String text) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              color: Color(0xFF636E72),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _Plan {
  final String label;
  final String price;
  final String period;
  final String? badge;

  const _Plan(this.label, this.price, this.period, this.badge);
}
