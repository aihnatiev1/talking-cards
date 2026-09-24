/// Bilingual copy for the App Store preview — edit here to tweak messaging.
/// Keep each line short: video frames are 4–5 seconds each.

export type Locale = 'uk' | 'en';

export interface PreviewCopy {
  tagline: string;       // opening title card
  features: string[];    // 5 short feature bullets, one per screenshot
  closing: string;       // final frame text
  cta: string;           // call-to-action on last frame
  familyBadge: string;   // multi-profile sell line under CTA (App Store only)
}

export const copy: Record<Locale, PreviewCopy> = {
  uk: {
    tagline: 'Картки-розмовлялки',
    features: [
      // feature-1 — packs grid hero
      'Обирай\nрозділ',
      // feature-2 — card detail (illustration + word + phrase)
      'Слухай\nі вивчай',
      // feature-3 — quiz game in action
      'Грайся',
      // feature-4 — coloring screen
      'Малюй',
      // feature-5 — parent dashboard
      'Статистика\nдля батьків',
    ],
    closing: 'Перші слова —\nразом!',
    cta: 'Завантажуй зараз',
    familyBadge: '👨‍👩‍👧‍👦 Кілька профілів · одна підписка',
  },
  en: {
    tagline: 'FirstWords Cards',
    features: [
      'Pick a\npack',
      'Listen\nand learn',
      'Play',
      'Color',
      "Track\nprogress",
    ],
    closing: 'First words —\ntogether!',
    cta: 'Download now',
    familyBadge: '👨‍👩‍👧‍👦 Multiple kids · one subscription',
  },
};
