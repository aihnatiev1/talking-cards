import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:integration_test/integration_test.dart';
import 'package:talking_cards/services/purchase_service.dart';

/// Asks the real store on this device what it knows about our SKUs.
///
/// Android has produced 55 paywall views and 2 purchase_start events in 90
/// days while iOS turns a quarter of its views into a checkout, so the
/// question is whether the catalogue ever arrives on Play at all. Nothing
/// here buys anything: it queries, prints and asserts nothing, because on a
/// device without a Play account "unavailable" is the correct answer and
/// still worth seeing.
///
///   flutter test integration_test/play_billing_probe_test.dart -d `<device>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('what the store answers', (tester) async {
    final iap = InAppPurchase.instance;

    final t0 = DateTime.now();
    final available = await iap.isAvailable();
    print('PROBE isAvailable=$available '
        'in ${DateTime.now().difference(t0).inMilliseconds}ms');

    final t1 = DateTime.now();
    final res = await iap.queryProductDetails(
        {'yearly_premium', 'monthly_premium', 'lifetime_premium'});
    print('PROBE query in ${DateTime.now().difference(t1).inMilliseconds}ms '
        'error=${res.error} notFound=${res.notFoundIDs}');
    for (final p in res.productDetails) {
      print('PROBE product ${p.id} "${p.title}" ${p.price} '
          'raw=${p.rawPrice} ${p.currencyCode}');
    }

    final t2 = DateTime.now();
    final loaded = await PurchaseService.instance.ensureProducts();
    print('PROBE ensureProducts=$loaded '
        'in ${DateTime.now().difference(t2).inMilliseconds}ms '
        'products=${PurchaseService.instance.products.map((p) => p.id).toList()}');
  });
}
