# Phase 9 — Games Block + Sort Game + Age Levels

**Goal:** Move games out of the pack grid into a dedicated "Games" section. Add Sort It! drag-drop game. Age/level selector is optional for this phase.

**Status:** not started

---

## Context

Current state in `home_screen.dart`:
- Quiz tile inserted at grid position 5 (`quizPosition = 5`) via `_GridItem.quiz`
- Memory tile inserted at grid position 7 (`memoryPosition = 7`) via `_GridItem.memory`
- Both are mixed into the pack grid — creates layout irregularities when categories filter

Target state:
- A horizontal `_GamesSection` row **above** the category chips + pack grid
- Pack grid contains only packs (+ favorites + review virtual packs)
- New "Sort It!" game added to the Games section

---

## Tasks

### Task 1 — Remove Quiz/Memory from pack grid

**File:** `lib/screens/home_screen.dart`

1. Delete `_GridItem.quiz(...)` and `_GridItem.memory(...)` factory constructors and the `isQuiz` / `isMemory` getters from `_GridItem`
2. Remove the quiz/memory insertion blocks from the grid-building loop (lines ~663-691):
   - Remove `if (i == quizPosition && playableCount >= 4) { gridItems.add(_GridItem.quiz(allCards)); }`
   - Remove `if (i == memoryPosition && playableCount >= 6) { gridItems.add(_GridItem.memory(allCards)); }`
   - Remove the tail-of-list fallback insertions for quiz/memory
3. Remove the `if (item.isQuiz)` and `if (item.isMemory)` branches from `GridView.builder.itemBuilder`
4. Keep `_openQuiz` and `_openMemoryMatch` methods — they will be called from the new `_GamesSection`

**Success check:** Grid shows only packs + favorites + review. No quiz/memory tiles mixed in.

---

### Task 2 — Add _GamesSection widget

**File:** `lib/screens/home_screen.dart` (add widget at bottom of file)

Insert `_GamesSection` in the `build()` Column between the SRS banner and the category chips:

```dart
// Games section
_GamesSection(
  allCards: allCards,
  isEnMode: isEnMode,
  onQuiz: () => _openQuiz(allCards),
  onMemory: () => _openMemoryMatch(allCards),
  onSort: () => _openSortGame(allCards, packs),
),
```

**`_GamesSection` widget spec:**
- `ConsumerWidget` (needs language for labels)
- Horizontal `SingleChildScrollView` with 3 game cards side-by-side
- Each card: rounded rect, emoji icon, label, tap handler
- Show only if `playableCount >= 4`
- Three games:
  - 🎧 **Вгадай слово** / **Guess the word** (quiz)
  - 🧠 **Знайди пару** / **Find the pair** (memory)
  - 🗂️ **Розклади** / **Sort it!** (sort game)
- Sort card disabled (greyed) if fewer than 2 non-special packs available

**Add `_openSortGame` method to `_HomeScreenState`:**
```dart
void _openSortGame(List<CardModel> allCards, List<PackModel> packs) {
  final playablePacks = packs.where((p) => !p.id.startsWith('_') && !p.isLocked && p.cards.length >= 3).toList();
  if (playablePacks.length < 2) return;
  playablePacks.shuffle();
  final packA = playablePacks[0];
  final packB = playablePacks[1];
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => SortGameScreen(packA: packA, packB: packB)),
  );
}
```

---

### Task 3 — Create SortGameScreen

**File:** `lib/screens/sort_game_screen.dart` (new file)

**Game mechanics:**
- Receive `packA` and `packB` (two `PackModel`s)
- Take 3 cards from each pack (random, shuffled together = 6 cards total)
- Display cards in a wrap/grid at top
- Two `DragTarget` zones at bottom labelled with pack title + icon
- `Draggable<CardModel>` for each card
- When card dropped on correct zone → card disappears, score++
- When card dropped on wrong zone → shake feedback, card returns
- All 6 correctly sorted → show completion dialog with star rating
- On completion: `ref.read(dailyQuestProvider.notifier).completeTask(QuestTask.reviewOldCard)`

**Screen structure:**
```
AppBar: "Розклади / Sort It!" + back button
Body:
  ├── Progress indicator (X of 6 sorted)
  ├── Cards area (Wrap of remaining cards as Draggable)
  └── Bottom row:
      ├── DragTarget Zone A (packA title + color)
      └── DragTarget Zone B (packB title + color)
```

**Widget sketch:**
```dart
class SortGameScreen extends ConsumerStatefulWidget {
  final PackModel packA;
  final PackModel packB;
}

class _SortGameScreenState extends ConsumerState<SortGameScreen> {
  late List<CardModel> _remaining; // cards left to sort
  int _score = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final cardsA = (widget.packA.cards..shuffle()).take(3).toList();
    final cardsB = (widget.packB.cards..shuffle()).take(3).toList();
    _remaining = [...cardsA, ...cardsB]..shuffle();
  }

  void _onCorrectDrop(CardModel card) {
    setState(() {
      _remaining.remove(card);
      _score++;
      if (_remaining.isEmpty) _done = true;
    });
    if (_done) _showCompletion();
  }
}
```

**Cards displayed as:** image (or emoji) + word label, sized ~80×100, with pack color background

**DragTarget zone appearance:**
- `Container` with pack color (low opacity bg), dashed border when active
- Shows pack icon (emoji) + title
- `isLocked` highlight when hovering with correct card

**Completion dialog:**
- "Все розкладено! 🎉" / "All sorted! 🎉"
- 3 stars always (it's a kids' game — positive reinforcement)
- "Грати ще!" / "Play again!" → same packs, re-shuffle
- "Додому" / "Home" → Navigator.pop()

---

### Task 4 — Age/Level in Profile (optional)

**Status:** Optional for Phase 9. Skip if scope is too large.

If included:
1. Add `level` field to `ProfileModel` (default `2`)
2. Update `ProfileModel.fromJson` / `toJson` with `'level'` key
3. Add level selector row in `_ProfileEditDialog` in `profile_selector_screen.dart`
4. Level options: 1 (🍼 1-2y), 2 (🐣 2-3y), 3 (🌟 3-4y), 4 (🚀 4-5y)
5. Level currently does NOT gate any content — just stored on profile (UI only for now)

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/screens/sort_game_screen.dart` | New Sort It! game |

## Files to Modify

| File | Change |
|------|--------|
| `lib/screens/home_screen.dart` | Remove quiz/memory from grid, add `_GamesSection`, add `_openSortGame` |
| `lib/models/profile_model.dart` | Add `level` field (optional, Task 4) |
| `lib/screens/profile_selector_screen.dart` | Add level selector (optional, Task 4) |

---

## Success Criteria

- [ ] Games section visible above pack grid with 3 game buttons
- [ ] Quiz + Memory removed from pack grid (no more misaligned tiles)
- [ ] Sort game launches from Games section
- [ ] Sort game: 6 cards from 2 packs, drag-drop sorting works
- [ ] Correctly sorted cards disappear; wrong drops return with feedback
- [ ] Sorting all 6 cards shows completion dialog
- [ ] Completing sort game marks `reviewOldCard` quest task done
- [ ] Works on iPhone SE (no overflow)
- [ ] Both EN and UK modes show correct game labels
