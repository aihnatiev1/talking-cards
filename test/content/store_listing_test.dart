import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talking_cards/models/pack_model.dart';

/// A store listing that names a free pack the app charges for is the one
/// kind of copy mistake that costs a refund and a one-star review. The
/// free packs live in the card data, so the listing is checked against it.
void main() {
  List<PackModel> packs(String file) =>
      (json.decode(File('assets/data/$file').readAsStringSync())
              as List<dynamic>)
          .map((p) => PackModel.fromJson(p as Map<String, dynamic>))
          .toList();

  List<String> freeTitles(String file) => [
        for (final p in packs(file))
          if (!p.isLocked && !p.id.startsWith('_')) p.title,
      ];

  test('Ukrainian listings name the packs that are actually free', () {
    final free = freeTitles('uk_cards.json');
    expect(free, hasLength(3));

    for (final path in [
      'ios/fastlane/metadata/uk/description.txt',
      'android/fastlane/metadata/android/uk-UA/full_description.txt',
    ]) {
      final text = File(path).readAsStringSync();
      for (final title in free) {
        expect(text, contains(title), reason: '$path never names «$title»');
      }
      expect(
        text,
        isNot(contains('Звук Р —')),
        reason: '$path still offers the Р pack, which is paid now',
      );
    }
  });

  test('English listings count the free packs correctly', () {
    final free = freeTitles('en_cards.json');
    expect(free, hasLength(2));

    for (final path in [
      'ios/fastlane/metadata/en-US/description.txt',
      'ios/fastlane/metadata/en-GB/description.txt',
      'ios/fastlane/metadata/en-AU/description.txt',
      'ios/fastlane/metadata/en-CA/description.txt',
      'android/fastlane/metadata/android/en-US/full_description.txt',
    ]) {
      final text = File(path).readAsStringSync();
      expect(
        text,
        contains('${free.length} STARTER PACKS FREE'),
        reason: '$path promises the wrong number of free packs',
      );
      expect(
        text,
        isNot(contains('Sound R — first articulation pack')),
        reason: '$path still offers the R pack, which is paid now',
      );
    }
  });

  /// Apple gives the keyword field 100 characters and indexes the name and
  /// subtitle anyway, so a word spent twice is a word not spent. Spaces
  /// after commas cost a character each and buy nothing.
  test('iOS keyword fields fit and waste nothing', () {
    for (final loc in ['uk', 'en-US', 'en-GB', 'en-AU', 'en-CA']) {
      final dir = 'ios/fastlane/metadata/$loc';
      final keywords = File('$dir/keywords.txt').readAsStringSync().trim();
      expect(keywords.length, lessThanOrEqualTo(100),
          reason: '$loc keywords are ${keywords.length} characters');
      expect(keywords, isNot(contains(' ')), reason: '$loc wastes a space');

      final tokens = keywords.split(',');
      expect(tokens.toSet(), hasLength(tokens.length),
          reason: '$loc repeats a keyword');

      final indexed = ('${File('$dir/name.txt').readAsStringSync()} '
              '${File('$dir/subtitle.txt').readAsStringSync()}')
          .toLowerCase();
      for (final token in tokens) {
        if (token.length < 4) continue; // "2", "abc" are cheap either way
        expect(indexed, isNot(contains(token.toLowerCase())),
            reason: '$loc spends a keyword on «$token», '
                'which the name or subtitle already indexes');
      }
    }
  });
}
