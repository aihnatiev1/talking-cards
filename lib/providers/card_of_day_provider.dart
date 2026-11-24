import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_model.dart';
import '../models/pack_model.dart';
import '../utils/pack_categories.dart';

/// Shared daily selection; evaluated with current packs at each home rebuild.
/// A selector rather than a cached card keeps the original date-based behavior.
final cardOfDaySelectorProvider =
    Provider<(CardModel, bool)? Function(List<PackModel>)>(
      (ref) => cardOfTheDay,
    );
