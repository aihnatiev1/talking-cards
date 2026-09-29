import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/services/remote_config_service.dart';

/// With no value from the server — which is what the console delivered for
/// `locked_pack_tap` from 27 to 30 Sep 2026 — a tap on a locked pack must
/// open the paywall, the only door that sold between 29 Aug and 14 Sep.
void main() {
  test('a locked pack opens the paywall unless the console says preview', () {
    expect(RemoteConfigService.instance.lockedPackTapOpensPreview, isFalse);
  });
}
