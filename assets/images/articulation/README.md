# Articulation illustrations

One drawing per exercise in `lib/screens/articulation_screen.dart`, named
after the exercise id: `<id>.webp`.

    spatula  needle  clock   swing
    mushroom horse   painter jam
    tube     smile   balloon cup

What the drawing has to show is the *position*: where the tongue is against
the teeth and the palate, what the lips do. A parent reads the steps aloud
and copies the picture at a mirror — 🍄 for «Грибок» told them nothing,
which is why the emoji are gone.

Missing files are not a fault: `ArticulationArt`
(`lib/widgets/articulation_art.dart`) draws a painted mouth in the slot
until the file lands, and picks the real drawing up with no code change.

This file also keeps the directory non-empty so the `pubspec.yaml` asset
entry always resolves.
