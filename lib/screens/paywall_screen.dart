import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/language_provider.dart';
import '../providers/packs_provider.dart';
import '../services/analytics_service.dart';
import '../services/purchase_service.dart';
import '../services/remote_config_service.dart';
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import '../utils/l10n.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  /// When true, shows the onboarding-specific welcome variant: stronger
  /// headline, multiple testimonials, and an explicit "continue free" CTA
  /// instead of relying on the close X (more honest UX for first-time users).
  final bool isOnboarding;

  const PaywallScreen({super.key, this.isOnboarding = false});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _loading = false;
  int _selectedPlan = 0;
  bool _canCloseEarly = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logPaywallView(
      widget.isOnboarding ? 'paywall_onboarding' : 'paywall_screen',
    );
    // Industry standard: give the user 3s to read the offer before exposing X.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _canCloseEarly = true);
    });
  }

  List<_Plan> _buildPlans(AppS s) {
    final products = PurchaseService.instance.products;
    final labelYearly = s('Річна', 'Yearly');
    final labelMonthly = s('Місячна', 'Monthly');
    final badgeBest = s('Найвигідніше', 'Best value');
    final perYear = s('/рік', '/year');
    final perMonth = s('/місяць', '/month');

    // Use the live store price everywhere when products are loaded — Apple
    // and Google return it already formatted in the user's region currency
    // (грн for UA, $ for US, € for EU, etc.). The hardcoded fallback below
    // is only for offline / first-launch while the store query is pending.
    if (products.isEmpty) {
      return [
        _Plan(labelYearly, s('449 грн', '\$14.99'), perYear, badgeBest,
            productId: 'yearly_premium'),
        _Plan(labelMonthly, s('79 грн', '\$1.99'), perMonth, null,
            productId: 'monthly_premium'),
      ];
    }

    return products.map((p) {
      switch (p.id) {
        case 'yearly_premium':
          return _Plan(labelYearly, p.price, perYear, badgeBest,
              productId: p.id);
        case 'monthly_premium':
          return _Plan(labelMonthly, p.price, perMonth, null,
              productId: p.id);
        default:
          return _Plan(p.title, p.price, '', null, productId: p.id);
      }
    }).toList();
  }

  Future<void> _purchase() async {
    final s = AppS(ref.read(languageProvider) == 'en');
    final plan = _buildPlans(s)[_selectedPlan];
    AnalyticsService.instance.logPurchaseStart(plan.productId);
    setState(() => _loading = true);
    try {
      final success =
          await PurchaseService.instance.purchaseByProductId(plan.productId);
      if (!mounted) return;
      if (!success) {
        // `buyNonConsumable` returns false when the user dismisses the
        // system purchase sheet or the store rejects the request
        // pre-flight. Treat both as a cancel from the funnel's POV.
        AnalyticsService.instance.logPurchaseCancel(plan.productId);
        setState(() => _loading = false);
        return;
      }
      await _waitForPro();
      if (!mounted) return;
      setState(() => _loading = false);

      if (PurchaseService.instance.isPro.value) {
        AnalyticsService.instance.logPurchaseSuccess(plan.productId);
        await AnalyticsService.instance.setProProperty(true);
        ref.read(isProProvider.notifier).state = true;
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        // Timed out waiting for the purchase stream to deliver — surface
        // as error so we can distinguish from user cancels in analytics.
        AnalyticsService.instance
            .logPurchaseError(plan.productId, 'pro_not_granted');
      }
    } catch (e) {
      AnalyticsService.instance
          .logPurchaseError(plan.productId, e.toString());
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Waits for isPro to become true, or times out after 10 seconds.
  Future<void> _waitForPro() async {
    if (PurchaseService.instance.isPro.value) return;
    final completer = Completer<void>();
    void listener() {
      if (PurchaseService.instance.isPro.value && !completer.isCompleted) {
        completer.complete();
      }
    }
    PurchaseService.instance.isPro.addListener(listener);
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
    PurchaseService.instance.isPro.removeListener(listener);
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
      final s = AppS(ref.read(languageProvider) == 'en');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(s('Підписку не знайдено', 'No subscription found'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider) == 'en';
    final s = AppS(isEn);
    final plans = _buildPlans(s);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kAccent.withValues(alpha: 0.06),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _canCloseEarly ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_canCloseEarly,
                    child: IconButton(
                      onPressed: () {
                        AnalyticsService.instance.logPaywallDismiss(
                          widget.isOnboarding
                              ? 'paywall_onboarding'
                              : 'paywall_screen',
                        );
                        Navigator.of(context).pop(false);
                      },
                      icon: Icon(Icons.close,
                          color: Colors.grey[400], size: 28),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    _trialBanner(context, s),
                    const SizedBox(height: 18),
                    Text(
                      s(
                        RemoteConfigService.instance.paywallTitle,
                        'Unlock full potential',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: responsiveFont(context, 22),
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.headlineSmall?.color,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _benefit(
                        Icons.grid_view_rounded,
                        s('19 розділів для розвитку',
                            '19 learning packs')),
                    const SizedBox(height: 10),
                    _benefit(
                        Icons.volume_up_rounded,
                        s('400+ яскравих карток зі звуком',
                            '400+ vivid cards with sound')),
                    const SizedBox(height: 10),
                    _benefit(Icons.auto_awesome_rounded,
                        s('Нові розділи щомісяця', 'New packs every month')),
                    const SizedBox(height: 18),
                    _testimonial(s),
                    const SizedBox(height: 22),
                    ...List.generate(plans.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _planTile(i, plans),
                      );
                    }),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: kAccent.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _loading ? null : _purchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          elevation: 0,
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
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  s(
                                    RemoteConfigService.instance.paywallCta,
                                    'Start 3-day free trial',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s(
                        '3 дні безкоштовно, потім ${plans[_selectedPlan].price}${plans[_selectedPlan].period} • Скасувати будь-коли',
                        '3 days free, then ${plans[_selectedPlan].price}${plans[_selectedPlan].period} • Cancel anytime',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: responsiveFont(context, 13),
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _loading ? null : _restore,
                      child: Text(
                        s('Відновити покупки', 'Restore purchases'),
                        style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: responsiveFont(context, 15),
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (widget.isOnboarding)
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                AnalyticsService.instance.logPaywallDismiss(
                                    'paywall_onboarding_skip');
                                Navigator.of(context).pop(false);
                              },
                        child: Text(
                          s('Продовжити з безкоштовними розділами',
                              'Continue with free packs'),
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: responsiveFont(context, 13),
                              fontWeight: FontWeight.w500),
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
                          _legalLink(
                              s('Умови використання', 'Terms of Use'),
                              isEn
                                  ? 'https://aihnatiev1.github.io/talking-cards/terms-en.html'
                                  : 'https://aihnatiev1.github.io/talking-cards/terms.html'),
                          _legalLink('EULA', 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                          _legalLink(
                              s('Конфіденційність', 'Privacy'),
                              isEn
                                  ? 'https://aihnatiev1.github.io/talking-cards/privacy-policy-en.html'
                                  : 'https://aihnatiev1.github.io/talking-cards/privacy-policy.html'),
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
          fontSize: responsiveFont(context, 13),
          color: Colors.grey[500],
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _planTile(int index, List<_Plan> plans) {
    final plan = plans[index];
    final selected = _selectedPlan == index;
    const tileColor = kAccent;

    return GestureDetector(
      onTap: () {
        if (_selectedPlan != index) {
          AnalyticsService.instance.logPaywallProductSelect(plan.productId);
        }
        setState(() => _selectedPlan = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? tileColor.withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? tileColor : Colors.grey.shade200,
            width: selected ? 3 : 1.5,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: tileColor.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Radio dot
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? tileColor : Colors.grey.shade400,
                  width: 2,
                ),
                color: selected ? tileColor : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            // Label + badge
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      plan.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: selected ? tileColor : null,
                      ),
                    ),
                  ),
                  if (plan.badge != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: plan.badgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          plan.badge!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: selected ? tileColor : Colors.grey[700],
                  ),
                ),
                if (plan.period.isNotEmpty)
                  Text(
                    plan.period,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _trialBanner(BuildContext context, AppS s) {
    final isOnb = widget.isOnboarding;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kAccent.withValues(alpha: 0.18),
            const Color(0xFFF9A825).withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kAccent.withValues(alpha: 0.30), width: 1.5),
      ),
      child: Column(
        children: [
          Text(isOnb ? '🎉' : '🎁', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 6),
          if (isOnb) ...[
            Text(
              s('ВІТАЄМО!', 'WELCOME!'),
              style: TextStyle(
                fontSize: responsiveFont(context, 14),
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF9A825),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            s('3 ДНІ БЕЗКОШТОВНО', '3 DAYS FREE'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsiveFont(context, 24),
              fontWeight: FontWeight.w900,
              color: kAccent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isOnb
                ? s('Подарунок для нових родин — скасуй будь-коли',
                    'A gift for new families — cancel anytime')
                : s('Без зобов\'язань — скасуй будь-коли',
                    'No commitment — cancel anytime'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsiveFont(context, 13),
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _testimonial(AppS s) {
    if (!widget.isOnboarding) {
      return _testimonialCard(
        s(
          '«Дуже подобається додаток, дякую!\nДитина в захваті 😍»',
          '“Love this app, thank you!\nMy kid is obsessed 😍”',
        ),
        s('Оксана', 'Oksana'),
      );
    }
    // Onboarding variant: 3 quotes for stronger social proof
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (_) => const Icon(
              Icons.star_rounded,
              color: Color(0xFFFFB300),
              size: 22,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s('4.9 із 5 — App Store', '4.9 out of 5 — App Store'),
          style: TextStyle(
            fontSize: responsiveFont(context, 13),
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _testimonialCard(
          s('«Дитина в захваті 😍 Дуже подобається!»',
              '“My kid is obsessed 😍 Really loves it!”'),
          s('Оксана', 'Oksana'),
        ),
        const SizedBox(height: 8),
        _testimonialCard(
          s(
              '«Я вражений якістю контенту. Раджу всім, у кого є діти!»',
              '“Impressed by the content quality. Recommend to every parent!”'),
          s('Дмитро', 'Dmitri'),
        ),
        const SizedBox(height: 8),
        _testimonialCard(
          s('«Дитині подобається — і це головне»',
              '“Kid loves it — that\'s what matters”'),
          s('Анна', 'Anna'),
        ),
      ],
    );
  }

  Widget _testimonialCard(String quote, String author) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFFFC107).withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          if (!widget.isOnboarding) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (_) => const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFB300),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            quote,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsiveFont(context, 14),
              fontStyle: FontStyle.italic,
              color: const Color(0xFF4A3F1A),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '— $author, App Store',
            style: TextStyle(
              fontSize: responsiveFont(context, 12),
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefit(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kAccent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: responsiveFont(context, 16),
              color: const Color(0xFF3A3A3A),
              height: 1.3,
              fontWeight: FontWeight.w500,
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
  final String period; // empty for one-time purchase
  final String? badge;
  final Color badgeColor = const Color(0xFFFF6B6B);
  final String productId;

  const _Plan(
    this.label,
    this.price,
    this.period,
    this.badge, {
    required this.productId,
  });
}
