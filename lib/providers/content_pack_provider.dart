import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/asset_pack_service.dart';

/// Download state of the paid-content asset pack, for widgets that have to
/// show "still arriving" instead of a broken card. Bridges the service's
/// ValueNotifier so the UI reads it like every other provider.
final contentPackProvider =
    StateNotifierProvider<ContentPackNotifier, ContentPackState>(
      (ref) => ContentPackNotifier(AssetPackService.instance),
    );

class ContentPackNotifier extends StateNotifier<ContentPackState> {
  ContentPackNotifier(this._service) : super(_service.state.value) {
    _service.state.addListener(_sync);
  }

  final AssetPackService _service;

  void _sync() => state = _service.state.value;

  @override
  void dispose() {
    _service.state.removeListener(_sync);
    super.dispose();
  }
}
