import React from 'react';
import { AbsoluteFill, Audio, Sequence, staticFile } from 'remotion';
import { z } from 'zod';
import { copy } from './copy';
import { TitleCard } from './scenes/TitleCard';
import { FeatureCard } from './scenes/FeatureCard';
import { ClosingCard } from './scenes/ClosingCard';

export const tikTokSchema = z.object({
  locale: z.enum(['uk', 'en']),
});

// Tight 15-second cut for TikTok / Reels — 30fps, 450 frames total.
// Pacing assumes the viewer might scroll past at any moment, so every
// frame is doing work: 1s title, then 5×2.5s features, then 1.5s closing.
//
//   0–30   (1.0s) Title — punchy hook
//  30–105  (2.5s) Feature 1 — Обирай розділ
// 105–180  (2.5s) Feature 2 — Слухай і вивчай
// 180–255  (2.5s) Feature 3 — Грайся
// 255–330  (2.5s) Feature 4 — Малюй
// 330–405  (2.5s) Feature 5 — Статистика для батьків
// 405–450  (1.5s) Closing + CTA
export const TikTokPreview: React.FC<z.infer<typeof tikTokSchema>> = ({
  locale,
}) => {
  const c = copy[locale];
  return (
    <AbsoluteFill
      style={{
        background: 'linear-gradient(180deg, #FFF8F0 0%, #FFEDD8 55%, #FDE2C8 100%)',
        fontFamily: 'Fredoka, system-ui, sans-serif',
      }}
    >
      {/* Background music — clipped to the 15s cut, with 0.5s fades. */}
      <Audio
        src={staticFile('music/bg.mp3')}
        volume={(f) => {
          if (f < 15) return (f / 15) * 0.5;
          if (f > 435) return ((450 - f) / 15) * 0.5;
          return 0.5;
        }}
      />

      <Sequence from={0} durationInFrames={30}>
        <TitleCard title={c.tagline} />
      </Sequence>

      <Sequence from={30} durationInFrames={75}>
        <FeatureCard
          text={c.features[0]}
          screenshot={staticFile(`screenshots/feature-1-${locale}.png`)}
          accent="#6C63FF"
        />
      </Sequence>

      <Sequence from={105} durationInFrames={75}>
        <FeatureCard
          text={c.features[1]}
          screenshot={staticFile(`screenshots/feature-2-${locale}.png`)}
          accent="#E91E63"
        />
      </Sequence>

      <Sequence from={180} durationInFrames={75}>
        <FeatureCard
          text={c.features[2]}
          screenshot={staticFile(`screenshots/feature-3-${locale}.png`)}
          accent="#00BFA5"
        />
      </Sequence>

      <Sequence from={255} durationInFrames={75}>
        <FeatureCard
          text={c.features[3]}
          screenshot={staticFile(`screenshots/feature-4-${locale}.png`)}
          accent="#FF8C42"
        />
      </Sequence>

      <Sequence from={330} durationInFrames={75}>
        <FeatureCard
          text={c.features[4]}
          screenshot={staticFile(`screenshots/feature-5-${locale}.png`)}
          accent="#1A5276"
        />
      </Sequence>

      <Sequence from={405} durationInFrames={45}>
        <ClosingCard closing={c.closing} cta={c.cta} />
      </Sequence>
    </AbsoluteFill>
  );
};
