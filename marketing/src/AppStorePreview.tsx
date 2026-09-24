import React from 'react';
import { AbsoluteFill, Audio, Sequence, staticFile } from 'remotion';
import { z } from 'zod';
import { copy } from './copy';
import { TitleCard } from './scenes/TitleCard';
import { FeatureCard } from './scenes/FeatureCard';
import { ClosingCard } from './scenes/ClosingCard';

export const previewSchema = z.object({
  locale: z.enum(['uk', 'en']),
});

// Scene plan (30fps, total 900 frames / 30 sec — App Store Preview max):
//   0–60    (2.0s) Title card
//   60–210  (5.0s) Feature 1 — Обирай розділ
//  210–360  (5.0s) Feature 2 — Слухай і вивчай
//  360–510  (5.0s) Feature 3 — Грайся
//  510–630  (4.0s) Feature 4 — Малюй
//  630–780  (5.0s) Feature 5 — Статистика для батьків
//  780–900  (4.0s) Closing + CTA
export const AppStorePreview: React.FC<z.infer<typeof previewSchema>> = ({
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
      {/* Background music — quiet enough that App Store auto-mute looks
          fine, fades in/out at the edges. */}
      <Audio
        src={staticFile('music/bg.mp3')}
        volume={(f) => {
          if (f < 30) return (f / 30) * 0.45; // 1s fade-in
          if (f > 870) return ((900 - f) / 30) * 0.45; // 1s fade-out
          return 0.45;
        }}
      />

      <Sequence from={0} durationInFrames={60}>
        <TitleCard title={c.tagline} />
      </Sequence>

      <Sequence from={60} durationInFrames={150}>
        <FeatureCard
          text={c.features[0]}
          screenshot={staticFile(`screenshots/feature-1-${locale}.png`)}
          accent="#6C63FF"
        />
      </Sequence>

      <Sequence from={210} durationInFrames={150}>
        <FeatureCard
          text={c.features[1]}
          screenshot={staticFile(`screenshots/feature-2-${locale}.png`)}
          accent="#E91E63"
        />
      </Sequence>

      <Sequence from={360} durationInFrames={150}>
        <FeatureCard
          text={c.features[2]}
          screenshot={staticFile(`screenshots/feature-3-${locale}.png`)}
          accent="#00BFA5"
        />
      </Sequence>

      <Sequence from={510} durationInFrames={120}>
        <FeatureCard
          text={c.features[3]}
          screenshot={staticFile(`screenshots/feature-4-${locale}.png`)}
          accent="#FF8C42"
        />
      </Sequence>

      <Sequence from={630} durationInFrames={150}>
        <FeatureCard
          text={c.features[4]}
          screenshot={staticFile(`screenshots/feature-5-${locale}.png`)}
          accent="#1A5276"
        />
      </Sequence>

      <Sequence from={780} durationInFrames={120}>
        <ClosingCard
          closing={c.closing}
          cta={c.cta}
          familyBadge={c.familyBadge}
        />
      </Sequence>
    </AbsoluteFill>
  );
};
