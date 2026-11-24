/// A resumable, versioned lesson. Reward and completion share one document.
class PlaySession {
  const PlaySession({
    required this.topic,
    required this.cardIds,
    this.step = 0,
    this.assisted = const {},
    this.misses = 0,
    this.hint = false,
  });

  final String topic;
  final List<String> cardIds;
  // 0–2: explore; 3–5: find; 6: optional repeat; 7: complete.
  final int step;
  final Set<int> assisted;
  final int misses;
  final bool hint;
  bool get complete => step == 7;

  PlaySession copyWith({
    int? step,
    Set<int>? assisted,
    int? misses,
    bool? hint,
  }) => PlaySession(
    topic: topic,
    cardIds: cardIds,
    step: step ?? this.step,
    assisted: assisted ?? this.assisted,
    misses: misses ?? this.misses,
    hint: hint ?? this.hint,
  );

  Map<String, dynamic> toJson() => {
    'topic': topic,
    'cards': cardIds,
    'step': step,
    'assisted': assisted.toList(),
    'misses': misses,
    'hint': hint,
  };

  factory PlaySession.fromJson(Map<String, dynamic> json) {
    final cards = (json['cards'] as List).cast<String>();
    final step = json['step'] as int;
    if (cards.length != 3 ||
        cards.toSet().length != 3 ||
        step < 0 ||
        step > 7) {
      throw const FormatException('Invalid lesson');
    }
    return PlaySession(
      topic: json['topic'] as String,
      cardIds: List.unmodifiable(cards),
      step: step,
      assisted: (json['assisted'] as List).cast<int>().toSet(),
      misses: json['misses'] as int? ?? 0,
      hint: json['hint'] == true,
    );
  }
}

class PlayJournal {
  const PlayJournal({
    this.sessions = const {},
    this.rewards = const {},
    this.lastTopic,
  });
  final Map<String, PlaySession> sessions;
  final Set<String> rewards;
  final String? lastTopic;

  PlaySession? get current => sessions[lastTopic];

  PlayJournal put(PlaySession session) => PlayJournal(
    sessions: {...sessions, session.topic: session},
    rewards: session.complete ? {...rewards, session.topic} : rewards,
    lastTopic: session.topic,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'lastTopic': lastTopic,
    'rewards': rewards.toList(),
    'sessions': sessions.map((key, value) => MapEntry(key, value.toJson())),
  };

  factory PlayJournal.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported journal');
    }
    return PlayJournal(
      lastTopic: json['lastTopic'] as String?,
      rewards: (json['rewards'] as List).cast<String>().toSet(),
      sessions: (json['sessions'] as Map<String, dynamic>).map(
        (key, value) =>
            MapEntry(key, PlaySession.fromJson(value as Map<String, dynamic>)),
      ),
    );
  }
}
