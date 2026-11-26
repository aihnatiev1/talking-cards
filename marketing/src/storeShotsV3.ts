// Copy and layout for the 2026-11 clay redesign (StoreScreenshotV3).
// Captures come from tools/capture_store_screenshots.sh with
// SHOTS_DIR=marketing/public/screenshots/v3 — real app screens only.

export type V3Theme = 'sky' | 'meadow' | 'peach';

export type V3Friend = {
  /** assets/images/friends/<name>.webp, copied to public/friends */
  name: string;
  /** Feet position on the 1290×2796 canvas */
  x: number;
  y: number;
  size: number;
  flip?: boolean;
};

export type V3Slot = {
  file: string;
  headline: string;
  tint: string;
  sub: string;
  theme: V3Theme;
  tilt: number;
  /** The phone on its side (the farm) */
  landscape?: boolean;
  friends?: V3Friend[];
};

// Under the phone on its side: the farm's own animals, standing in a row.
const farmCrowd: V3Friend[] = [
  { name: 'horse', x: 230, y: 1850, size: 440 },
  { name: 'cow', x: 645, y: 1880, size: 490 },
  { name: 'rooster', x: 1060, y: 1850, size: 440, flip: true },
  { name: 'dog', x: 250, y: 2480, size: 430 },
  { name: 'pig', x: 650, y: 2520, size: 470 },
  { name: 'cat', x: 1050, y: 2480, size: 430, flip: true },
];

// One friend peeking in at the phone's lower corner.
const peek = (name: string, left: boolean): V3Friend[] => [
  { name, x: left ? 150 : 1140, y: 2800, size: 360, flip: !left },
];

const slots = (copy: Array<[string, string, string]>): V3Slot[] => {
  const layout: Array<Omit<V3Slot, 'headline' | 'tint' | 'sub'>> = [
    { file: 'farm', theme: 'sky', tilt: 0, landscape: true, friends: farmCrowd },
    { file: 'lesson', theme: 'meadow', tilt: 0, friends: peek('chicken', false) },
    { file: 'cards', theme: 'peach', tilt: 0, friends: peek('cat', false) },
    { file: 'home', theme: 'sky', tilt: 0, friends: peek('bird', true) },
    { file: 'games', theme: 'meadow', tilt: 3, friends: peek('dog', false) },
    { file: 'sounds', theme: 'peach', tilt: 0, friends: peek('owl', true) },
    { file: 'draw', theme: 'sky', tilt: 0, friends: peek('bee', false) },
  ];
  return layout.map((l, i) => ({
    ...l,
    headline: copy[i][0],
    tint: copy[i][1],
    sub: copy[i][2],
  }));
};

const withLocale = (list: V3Slot[], locale: 'en' | 'uk'): V3Slot[] =>
  list.map((s) => ({ ...s, file: `v3/refresh-${s.file}-${locale}.png` }));

export const storeShotsV3: Record<'en' | 'uk', V3Slot[]> = {
  uk: withLocale(
    slots([
      ['Тварини говорять', 'говорять', 'Торкнись корівки — почуй її «му»'],
      ['Почуй. Знайди.', 'Знайди.', 'Коротке заняття: три тваринки — один новий друг'],
      ['Перші слова вголос', 'вголос', 'Торкнись картинки — почуй слово'],
      ['Трошки гри щодня', 'щодня', 'На малюка щодня чекає коротке заняття'],
      ['Ігри, де звучать слова', 'слова', 'Шукаємо, порівнюємо, вгадуємо — і кажемо разом'],
      ['Р, Л, Ш — граючись', 'граючись', 'Звукові паки для занять удома й з логопедом'],
      ['Малюємо без реклами', 'без реклами', 'Розфарбовки, чарівна вода й наліпки'],
    ]),
    'uk',
  ),
  en: withLocale(
    slots([
      ['Animals That Talk', 'Talk', 'Tap the cow — hear her moo'],
      ['Hear It. Find It.', 'Find It.', 'Short lessons: three animals, one new friend'],
      ['First Words Aloud', 'Aloud', 'Tap a picture — hear the word'],
      ['A Little Play Every Day', 'Every Day', 'A short lesson waits for your child each day'],
      ['Games Full of Words', 'Words', 'Find, match, guess — and say it together'],
      ['R, L, S and Z Through Play', 'Through Play', 'Sound packs for home practice and speech therapy'],
      ['Draw Without Ads', 'Without Ads', 'Colouring, magic water and stickers'],
    ]),
    'en',
  ),
};
