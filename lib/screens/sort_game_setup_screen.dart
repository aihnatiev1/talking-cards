import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pack_model.dart';
import '../providers/language_provider.dart';
import '../utils/constants.dart';
import '../utils/l10n.dart';
import 'sort_game_screen.dart';

class SortGameSetupScreen extends ConsumerStatefulWidget {
  final List<PackModel> packs;

  const SortGameSetupScreen({super.key, required this.packs});

  @override
  ConsumerState<SortGameSetupScreen> createState() =>
      _SortGameSetupScreenState();
}

class _SortGameSetupScreenState extends ConsumerState<SortGameSetupScreen> {
  // Keeps insertion order so we know which was selected first
  final List<String> _selected = [];

  void _togglePack(PackModel pack) {
    setState(() {
      if (_selected.contains(pack.id)) {
        _selected.remove(pack.id);
      } else if (_selected.length < 2) {
        _selected.add(pack.id);
      } else {
        // Replace the first-selected with the new one
        _selected.removeAt(0);
        _selected.add(pack.id);
      }
    });
  }

  void _randomize() {
    final pool = List<PackModel>.from(widget.packs)..shuffle(Random());
    setState(() {
      _selected.clear();
      _selected.add(pool[0].id);
      _selected.add(pool[1].id);
    });
  }

  void _startGame() {
    if (_selected.length < 2) return;
    final packA = widget.packs.firstWhere((p) => p.id == _selected[0]);
    final packB = widget.packs.firstWhere((p) => p.id == _selected[1]);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SortGameScreen(packA: packA, packB: packB),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.read(languageProvider) == 'en';
    final s = AppS(isEn);
    final ready = _selected.length == 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s('Оберіть 2 розділи', 'Choose 2 categories'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Random button in app bar
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _randomize,
              icon: const Text('🎲', style: TextStyle(fontSize: 18)),
              label: Text(
                s('За мене!', 'Surprise!'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: kAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Selection counter
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  _SelectionDot(filled: _selected.isNotEmpty),
                  const SizedBox(width: 6),
                  _SelectionDot(filled: _selected.length >= 2),
                  const SizedBox(width: 12),
                  Text(
                    ready
                        ? s('Готово! Натисніть Грати', 'Ready! Tap Play')
                        : s(
                            'Оберіть ще ${2 - _selected.length}',
                            'Select ${2 - _selected.length} more',
                          ),
                    style: TextStyle(
                      fontSize: 13,
                      color: ready ? kAccent : Colors.grey[500],
                      fontWeight:
                          ready ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Pack grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
                itemCount: widget.packs.length,
                itemBuilder: (_, i) {
                  final pack = widget.packs[i];
                  final selIndex = _selected.indexOf(pack.id);
                  final isSelected = selIndex != -1;
                  return _PackTile(
                    pack: pack,
                    isSelected: isSelected,
                    selectionNumber: isSelected ? selIndex + 1 : null,
                    onTap: () => _togglePack(pack),
                  );
                },
              ),
            ),

            // Play button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: ready ? _startGame : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    disabledBackgroundColor: Colors.grey[200],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: ready ? 3 : 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (ready && _selected.length == 2) ...[
                        Text(
                          widget.packs
                              .firstWhere((p) => p.id == _selected[0])
                              .icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const Text(' vs ',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70)),
                        Text(
                          widget.packs
                              .firstWhere((p) => p.id == _selected[1])
                              .icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        s('Грати ▶', 'Play ▶'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Pack tile
// ─────────────────────────────────────────────

class _PackTile extends StatelessWidget {
  final PackModel pack;
  final bool isSelected;
  final int? selectionNumber; // 1 or 2 when selected
  final VoidCallback onTap;

  const _PackTile({
    required this.pack,
    required this.isSelected,
    required this.selectionNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? pack.color.withValues(alpha: 0.18)
              : pack.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? pack.color.withValues(alpha: 0.9)
                : pack.color.withValues(alpha: 0.25),
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(pack.icon,
                      style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      pack.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? pack.color : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Selection badge (1 or 2)
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: pack.color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$selectionNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Selection dot indicator
// ─────────────────────────────────────────────

class _SelectionDot extends StatelessWidget {
  final bool filled;
  const _SelectionDot({required this.filled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? kAccent : Colors.transparent,
        border: Border.all(
          color: filled ? kAccent : Colors.grey[400]!,
          width: 2,
        ),
      ),
    );
  }
}
