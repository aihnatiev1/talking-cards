// Config table for App Store screenshot Stills (StoreScreenshot composition).
// Edit copy here — the layout lives in StoreScreenshot.tsx.

export type StoreTheme = 'warm' | 'teal';

export type StoreSlotConfig = {
  /** File name inside public/screenshots/ */
  file: string;
  headline: string;
  /** Substring of headline to tint with the theme accent color */
  tintWord: string;
  sub: string;
  badges: string[];
  theme: StoreTheme;
  /** Device tilt in degrees (0 = upright) */
  tilt: number;
  /** Pixels (in 1290×2796 source coordinates) to crop off the top of the screenshot */
  cropTop: number;
  /** true = 58%-width fully-visible device, badges row layout (closing slot) */
  small: boolean;
};

export const storeShots: Record<'en' | 'uk', StoreSlotConfig[]> = {
  en: [
    {
      file: 'auto/refresh-cards-en.png',
      headline: 'First Words Aloud',
      tintWord: 'Aloud',
      sub: 'Tap a picture. Hear a word and a sentence.',
      badges: [],
      theme: 'warm',
      tilt: 0,
      cropTop: 0,
      small: false,
    },
    {
      file: 'auto/refresh-sounds-en.png',
      headline: 'Listen. Try. Repeat.',
      tintWord: 'Repeat.',
      sub: 'Explore sounds together, one card at a time.',
      badges: [],
      theme: 'teal',
      tilt: 0,
      cropTop: 0,
      small: false,
    },
    {
      file: 'auto/refresh-game-en.png',
      headline: 'Little Games, Big Smiles',
      tintWord: 'Smiles',
      sub: 'Listen, match and discover together',
      badges: [],
      theme: 'warm',
      tilt: 4,
      cropTop: 0,
      small: false,
    },
    {
      file: 'auto/refresh-draw-en.png',
      headline: 'Draw and Discover',
      tintWord: 'Draw',
      sub: 'Colour, stamp and explore together',
      badges: [],
      theme: 'teal',
      tilt: 0,
      cropTop: 0,
      small: false,
    },
    {
      file: 'auto/refresh-fill-en.png',
      headline: 'Tap a Colour, Tap a Part',
      tintWord: 'Colour',
      sub: 'Finish the picture and hear its name',
      badges: [],
      theme: 'warm',
      tilt: 0,
      cropTop: 0,
      small: false,
    },
    {
      file: 'auto/refresh-home-en.png',
      headline: 'A Little Play Every Day',
      tintWord: 'Every Day',
      sub: 'A daily invitation to explore together',
      badges: [],
      theme: 'teal',
      tilt: 0,
      cropTop: 0,
      small: false,
    },
    {
      file: 'auto/refresh-quest-en.png',
      headline: 'Play Without Ads',
      tintWord: 'Without Ads',
      sub: 'More time to explore together',
      badges: [],
      theme: 'warm',
      tilt: 0,
      cropTop: 0,
      small: false,
    },
  ],
  uk: [
    {
      file: 'auto/refresh-cards-uk.png',
      headline: 'Перші слова вголос',
      tintWord: 'Перші слова',
      sub: 'Торкнись картинки — почуй слово й речення',
      badges: [],
      theme: 'warm',
      tilt: 0,
      cropTop: 0,
      small: false,
    },
    {
      file: 'auto/refresh-sounds-uk.png',
      headline: 'Слухаємо. Повторюємо.',
      tintWord: 'Повторюємо.',
      sub: 'Знайомимося зі звуками разом',
      badges: [],
      theme: 'teal',
      tilt: 0,
      cropTop: 0,
      small: false,
    },
    {
      file: 'auto/refresh-game-uk.png',
      headline: 'Граємо зі словами',
      tintWord: 'Граємо',
      sub: 'Слухаємо, шукаємо, запам’ятовуємо',
      badges: [],
      theme: 'warm',
      tilt: 4,
      cropTop: 0,
      small: false,
    },
    {
      file: 'auto/refresh-draw-uk.png',
      headline: "Малюємо й відкриваємо",
      tintWord: 'Малюємо',
      sub: 'Фарби, наліпки та маленькі відкриття',
      badges: [],
      theme: 'teal',
      tilt: 0,
      cropTop: 0,
      small: false,
    },
    {
      file: 'auto/refresh-fill-uk.png',
      headline: 'Обери колір — тисни частинку',
      tintWord: 'колір',
      sub: 'Розфарбуй малюнок — почуй його назву',
      badges: [],
      theme: 'warm',
      tilt: 0,
      cropTop: 0,
      small: false,
    },
    {
      file: 'auto/refresh-home-uk.png',
      headline: "Маленькі кроки щодня",
      tintWord: 'щодня',
      sub: 'Нова пригода для спільних відкриттів',
      badges: [],
      theme: 'teal',
      tilt: 0,
      cropTop: 0,
      small: false,
    },
    {
      file: 'auto/refresh-quest-uk.png',
      headline: 'Граємо без реклами',
      tintWord: 'без реклами',
      sub: 'Більше часу для спільних відкриттів',
      badges: [],
      theme: 'warm',
      tilt: 0,
      cropTop: 0,
      small: false,
    },
  ],
};
