import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:audio_session/audio_session.dart';

import 'tts_service.dart';

/// Maps card image key (kirilic) to latin wav filename
const _audioMap = {
  // Розмовлялки
  'ай': 'ai', 'ан': 'an', 'ас': 'as', 'ах': 'ah',
  'ба': 'ba', 'бі': 'bi', 'ва': 'va', 'га': 'ga',
  'да': 'da', 'за': 'za', 'ла': 'la', 'ле': 'le',
  'му': 'mu', 'но': 'no', 'ой': 'oi', 'ок': 'ok',
  'ом': 'om', 'оп': 'op', 'ор': 'or', 'ос': 'os',
  'от': 'ot', 'ту': 'tu', 'ук': 'uk', 'уп': 'up',
  'ух': 'uh',
  // Тваринки
  'киця': 'kotik', 'песик': 'sobachka', 'корівка': 'korova',
  'коник': 'konik', 'свинка': 'svinka', 'курочка': 'kurochka',
  'півник': 'pivnik', 'качечка': 'kachechka', 'жабка': 'jabka',
  'рибка': 'ribka', 'пташка': 'ptashka', 'метелик': 'metelik',
  'бджола': 'bjilka', 'равлик': 'ravlik', 'зайчик': 'zaichik',
  'ведмідь': 'vednid', 'вовк': 'vovchik', 'олень': 'olen',
  'їжачок': 'ijachok', 'сова': 'sova', 'лисиця': 'lisicia',
  'лев': 'lev', 'слон': 'slon', 'дельфін': 'delfin',
  'крокодил': 'krokodil', 'пінгвін': 'pingvin', 'мавпочка': 'mavpochka',
  'білочка': 'bilochka', 'черепаха': 'cherepaha',
  // Вдома
  'мама': 'mama', 'тато': 'tato', 'бабуся': 'babusia',
  'дідусь': 'didus', 'ляля': 'lialia', 'родина': 'rodina',
  'обійми': 'obiimi', 'ранок': 'ranok', 'вечір': 'vechir',
  'радість': 'radist', 'сумно': 'sumno', 'сердитий': 'serditii',
  'страшно_д': 'strah', 'подив': 'podiv',
  'мʼяч': 'miach', 'лялька': 'lialka', 'машинка': 'mashinka',
  'книжка': 'knijka', 'кубики': 'kubiki', 'каша': 'kasha',
  'яблуко': 'yabluko', 'водичка': 'vodichka', 'гуляти': 'guliati',
  'ванна': 'vanna', 'мити_ручки': 'ruchki', 'чистити_зубки': 'zubki',
  'ліжко': 'lijko', 'дякую': 'diakuiu', 'будь ласка': 'budlaska',
  'любов': 'lubluiu',
  // Емоції
  'радість_е': 'radist_e', 'сумно_е': 'sumno_e', 'злість': 'zlist',
  'страх': 'strah', 'подив_е': 'podiv_e', 'любов_е': 'lubov_e',
  'сором': 'sorom', 'втома': 'vtoma', 'гордість': 'gordist',
  'цікавість': 'cikavist', 'спокій': 'spokii', 'ніжність': 'nijnist',
  'щастя': 'schastia', 'турбота': 'turbota', 'сміх': 'smih',
  'вдячність': 'vdiachnist', 'здвування': 'zdivuvanna',
  'нудьга': 'nudga', 'образа': 'obraza', 'довіра': 'dovira',
  'натхнення': 'nathnennia', 'хвилювання': 'hviluvania',
  'доброта': 'dobrota', 'сміливість': 'smilivist',
  'мир': 'mir', 'подяка': 'podiaka', 'увага': 'uvaga',
  'тепло': 'teplo', 'задоволення': 'zadovolennia',
  'співчуття': 'spivchutta',
  // Транспорт
  'автомобіль': 'avtomobil', 'автобус': 'avtobus', 'потяг': 'potiag',
  'літак': 'litak', 'корабель': 'korabel', 'велосипед': 'velosiped',
  'мотоцикл': 'motocikl', 'гелікоптер': 'gelikopter', 'трамвай': 'tramvai',
  'метро': 'metro', 'таксі': 'taksi', 'пожежна': 'pojejna',
  'швидка': 'shvidka', 'поліція': 'policia', 'вантажівка': 'vantajivka',
  'трактор': 'traktor', 'самокат': 'samokat', 'ракета': 'raketa',
  'човник': 'chovnik', 'яхта': 'yahta', 'повітряна_куля': 'povitryana_kulia',
  'санки': 'sanki', 'конячка': 'konyachka', 'карета': 'kareta',
  'скейтборд': 'skateboard', 'канатна_дорога': 'kanatna_doroga',
  'електричка': 'electrichka', 'екскаватор': 'ekskavator',
  'підводний_човен': 'pidvodnii_choven', 'параплан': 'paraplan',
  // Кольори та форми
  'червоний': 'red', 'синій': 'blue', 'жовтий': 'yellow',
  'зелений': 'green', 'білий': 'white', 'чорний': 'black',
  'помаранчевий': 'orange', 'рожевий': 'pink', 'фіолетовий': 'purple',
  'коричневий': 'brown', 'сірий': 'gray', 'блакитний': 'sky-blue',
  'золотий': 'gold', 'коло': 'circle', 'квадрат': 'square',
  'трикутник': 'triangle', 'зірка': 'star', 'серце_к': 'hart_k',
  'овал': 'oval', 'ромб': 'diamond', 'великий': 'big',
  'маленький': 'little', 'довгий': 'long', 'круглий': 'round',
  'пухнастий': 'fluffy', 'яскравий': 'bright', 'смугастий': 'striped',
  'плямистий': 'spotted', 'прозорий': 'transparent', 'різнобарвний': 'variegated',
  // Частини тіла
  'ніс': 'nose', 'голова': 'head', 'очі': 'eyes', 'вуха': 'ears',
  'рот': 'mouse', 'зуби': 'teeth', 'язик': 'tonge',
  'волосся': 'hair', 'шия': 'neck', 'плечі': 'sholdes',
  'руки': 'hands', 'пальчики': 'fingers', 'живіт': 'stomack',
  'спина': 'back', 'ноги': 'legs', 'коліна': 'knees',
  'ступні': 'foots', 'серце_т': 'hart_t', 'легені': 'lungs',
  'лікоть': 'elbow', 'долоні': 'palms', 'брови': 'eyebrows',
  'щоки': 'cheeks', 'чоло': 'forehead', 'підборіддя': 'chin',
  'нігті': 'neils', 'шкіра': 'skin', 'пупок': 'jellybutton',
  'усмішка': 'smile', 'тіло': 'body',
  // Їжа
  'яблуко_ї': 'yabluko_f', 'банан': 'banan', 'виноград': 'vinograd',
  'апельсин': 'apelsin', 'полуниця': 'polunicia', 'кавун': 'kavun',
  'груша': 'grusha', 'вишня': 'vishnia', 'персик': 'persik',
  'лимон': 'limon', 'хліб': 'hlib', 'молоко': 'moloko',
  'сир': 'sir', 'каша_ї': 'kasha_f', 'суп': 'sup',
  'пиріжок': 'pirijok', 'печиво': 'pechivo', 'торт': 'tort',
  'морозиво': 'morozivo', 'вареник': 'varenik', 'морква': 'morkva',
  'огірок': 'ogirok', 'помідор': 'pomidor', 'картопля': 'kartoplia',
  'кукурудза': 'kukurudza', 'гарбуз': 'garbuz', 'мед': 'med',
  'яєчко': 'yayechko', 'цукерка': 'cukerka', 'водичка_ї': 'vodichka_f',
};

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final _soloud = SoLoud.instance;
  final Map<String, AudioSource> _sources = {};

  final ValueNotifier<bool> isSpeaking = ValueNotifier(false);
  final ValueNotifier<bool> autoSpeak = ValueNotifier(false);
  int _speakGeneration = 0;

  Future<void> precache() async {
    // 1. Configure iOS audio session — playback ignores silent switch
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    ));
    await session.setActive(true);

    // 2. Initialize SoLoud engine (FFI — no method channels, lowest latency)
    await _soloud.init();

    // 3. Load all sounds into RAM
    for (final entry in _audioMap.entries) {
      try {
        final source = await _soloud.loadAsset('assets/audio_mp3/${entry.value}.mp3');
        _sources[entry.key] = source;
      } catch (e) {
        if (kDebugMode) debugPrint('AudioService: failed to load ${entry.key}: $e');
      }
    }

    if (kDebugMode) debugPrint('AudioService: ${_sources.length} sounds loaded into RAM');
  }

  Future<void> speakCard(String? audioKey, String sound, String fullText) async {
    if (audioKey == null) return;
    final source = _sources[audioKey];
    if (source == null) {
      if (kDebugMode) debugPrint('AudioService: no source for "$audioKey"');
      return;
    }

    final gen = ++_speakGeneration;
    try {
      // Stop previous sound before playing new one
      stop();
      isSpeaking.value = true;
      _currentHandle = await _soloud.play(source);
      final handle = _currentHandle;
      if (handle == null) {
        if (_speakGeneration == gen) isSpeaking.value = false;
        return;
      }
      while (_currentHandle == handle &&
          _soloud.getIsValidVoiceHandle(handle)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      // Only the latest speakCard call may clear isSpeaking
      if (_speakGeneration == gen) isSpeaking.value = false;
    } catch (e) {
      if (_speakGeneration == gen) isSpeaking.value = false;
      if (kDebugMode) debugPrint('AudioService: error playing "$audioKey": $e');
    }
  }

  /// Play just the sound for a given audio key (no speaking state tracking).
  /// Used by quiz mode.
  Future<void> playSound(String? audioKey) async {
    if (audioKey == null) return;
    final source = _sources[audioKey];
    if (source == null) {
      if (kDebugMode) debugPrint('AudioService: no source for "$audioKey"');
      return;
    }
    try {
      stop();
      _currentHandle = await _soloud.play(source);
    } catch (e) {
      if (kDebugMode) debugPrint('AudioService: error in playSound "$audioKey": $e');
    }
  }

  /// Play only the first word from a recorded audio file.
  ///
  /// Our audio files contain full sentences ("Коник каже іго-го!").
  /// Stops after an adaptive duration based on word syllable count:
  ///   900ms base (covers ~300ms leading silence) + 280ms per syllable.
  ///
  /// Examples:
  ///   КІТ (1 syllable)       → 1180ms
  ///   КОНИК (2 syllables)    → 1460ms
  ///   ЧЕРЕПАХА (4 syllables) → 2020ms
  ///
  /// Falls back to TTS if no audio file exists for this key.
  Future<void> playWordOnly(
    String? audioKey,
    String fallbackWord, {
    String locale = 'uk-UA',
  }) async {
    if (audioKey == null || !_sources.containsKey(audioKey)) {
      await TtsService.instance.speak(fallbackWord, locale: locale);
      return;
    }

    // Adaptive cutoff based on Ukrainian syllable count
    const vowels = {'А', 'Е', 'И', 'І', 'О', 'У', 'Є', 'Ї', 'Ю', 'Я'};
    final syllables = fallbackWord
        .toUpperCase()
        .split('')
        .where(vowels.contains)
        .length
        .clamp(1, 12);
    final stopAfterMs = 400 + (syllables * 180);

    final source = _sources[audioKey]!;
    // Generation counter ensures only the latest call can stop the audio.
    // If user flips card 2 while card 1 is still playing, card 1's timer
    // sees a different generation and does nothing.
    final gen = ++_speakGeneration;
    try {
      stop();
      isSpeaking.value = true;
      _currentHandle = await _soloud.play(source);
      Future.delayed(Duration(milliseconds: stopAfterMs), () {
        if (_speakGeneration == gen && _currentHandle != null) {
          try { stop(); } catch (_) {}
          isSpeaking.value = false;
        }
      });
    } catch (e) {
      if (_speakGeneration == gen) isSpeaking.value = false;
      if (kDebugMode) debugPrint('AudioService: playWordOnly error "$audioKey": $e');
    }
  }

  /// Whether a sound source exists for the given key.
  bool hasSound(String? key) => key != null && _sources.containsKey(key);

  SoundHandle? _currentHandle;

  void stop() {
    if (_currentHandle != null) {
      _soloud.stop(_currentHandle!);
      _currentHandle = null;
    }
    isSpeaking.value = false;
  }
}
