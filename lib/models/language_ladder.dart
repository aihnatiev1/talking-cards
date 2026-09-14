import 'card_model.dart';

/// What the child is asked to say for a word, and how far up from the
/// bare word it goes.
///
/// The app has always asked for the same thing forever: the word, alone,
/// on the first day and on the hundredth. A child who says «мама» reliably
/// is not helped by being asked for «мама» again — the next thing is
/// «мама йде», and after that a sentence. That progression is the ladder.
///
/// Only the rungs the recordings can actually carry exist here. Every card
/// already holds one file shaped WORD · silence · PHRASE, so [word] and
/// [sentence] work today with no new audio at all. The middle rungs — a
/// word plus a gesture, a two-word phrase — need takes that do not exist
/// yet, and they are deliberately absent rather than faked with the wrong
/// clip: a prompt the voice cannot say is worse than one less rung.
enum LadderRung {
  /// The word on its own, cut at the end of the word.
  word,

  /// The whole recording: the word, then the phrase it lives in.
  sentence,
}

/// One rung, resolved for one card.
class LadderStep {
  final LadderRung rung;

  /// What the grown-up is asked to have the child say, already in the
  /// right language — the card's own text, never invented here.
  final String prompt;

  const LadderStep({required this.rung, required this.prompt});

  /// Whether the whole recording plays, rather than just the word.
  bool get playsSentence => rung == LadderRung.sentence;
}

/// How many times a grown-up must mark a word before it moves up.
///
/// Three, and only from «Вийшло!» — the one signal in the app that came
/// from a human ear. Neither views nor microphone turns raise a rung: the
/// gate says "a voice happened", which is not "she says this word", and a
/// ladder built on it would climb away from a child who is not ready.
const int kRungUpAtMarks = 3;

/// The rung a card sits on for a child with [marks] grown-up marks.
LadderStep ladderStepFor(CardModel card, int marks) {
  final sentence = card.text.trim();
  final canClimb = marks >= kRungUpAtMarks &&
      sentence.isNotEmpty &&
      sentence.toLowerCase() != card.sound.trim().toLowerCase();
  return canClimb
      ? LadderStep(rung: LadderRung.sentence, prompt: sentence)
      : LadderStep(rung: LadderRung.word, prompt: card.sound);
}
