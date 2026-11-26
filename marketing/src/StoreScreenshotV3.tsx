import React from 'react';
import { AbsoluteFill, Img, staticFile } from 'remotion';
import { z } from 'zod';
import { loadFont as loadComfortaa } from '@remotion/google-fonts/Comfortaa';
import { loadFont as loadNunito } from '@remotion/google-fonts/Nunito';
import { storeShotsV3, V3Slot } from './storeShotsV3';

// The 2026-11 clay redesign. Same canvas and type as StoreScreenshot; the
// device holds a real capture (never generated art — guideline 2.3.3) and
// the app's own clay friends stand around it. The farm is on its side in
// the app, so its slide shows the phone on its side.
const comfortaa = loadComfortaa('normal', {
  weights: ['700'],
  subsets: ['latin', 'cyrillic'],
});
const nunito = loadNunito('normal', {
  weights: ['600', '700'],
  subsets: ['latin', 'cyrillic'],
});

export const storeScreenshotV3Schema = z.object({
  locale: z.enum(['en', 'uk']),
  slot: z.number().int().min(1).max(7),
});

const W = 1290;
const H = 2796;

const THEMES = {
  sky: {
    bg: 'linear-gradient(180deg, #CFEFFF 0%, #EAF8FF 55%, #DDF3D2 100%)',
    accent: '#2F6FCB',
  },
  meadow: {
    bg: 'linear-gradient(180deg, #E8F8DD 0%, #FFF8E8 100%)',
    accent: '#3E8A12',
  },
  peach: {
    bg: 'linear-gradient(180deg, #FFF1E2 0%, #FFE0C4 100%)',
    accent: '#B4511E',
  },
};

const Headline: React.FC<{ s: V3Slot }> = ({ s }) => {
  const accent = THEMES[s.theme].accent;
  const i = s.headline.indexOf(s.tint);
  const before = i >= 0 ? s.headline.slice(0, i) : s.headline;
  const tint = i >= 0 ? s.tint : '';
  const after = i >= 0 ? s.headline.slice(i + s.tint.length) : '';
  return (
    <div style={{ paddingTop: 150, textAlign: 'center' }}>
      <div
        style={{
          fontFamily: comfortaa.fontFamily,
          fontWeight: 700,
          fontSize: 112,
          lineHeight: 1.08,
          letterSpacing: '-0.01em',
          color: '#2D3436',
          padding: '0 60px',
        }}
      >
        {before}
        <span style={{ color: accent }}>{tint}</span>
        {after}
      </div>
      <div
        style={{
          fontFamily: nunito.fontFamily,
          fontWeight: 600,
          fontSize: 50,
          color: '#4F5A5E',
          marginTop: 30,
          padding: '0 100px',
          lineHeight: 1.35,
        }}
      >
        {s.sub}
      </div>
    </div>
  );
};

/** A clay friend from the app (assets/images/friends), standing. */
const Friend: React.FC<{
  name: string;
  x: number;
  y: number;
  size: number;
  flip?: boolean;
}> = ({ name, x, y, size, flip }) => (
  <Img
    src={staticFile(`friends/${name}.webp`)}
    style={{
      position: 'absolute',
      left: x - size / 2,
      top: y - size,
      width: size,
      height: size,
      objectFit: 'contain',
      objectPosition: 'bottom',
      transform: flip ? 'scaleX(-1)' : undefined,
      filter: 'drop-shadow(0 18px 24px rgba(45,52,54,0.18))',
    }}
  />
);

const Portrait: React.FC<{ s: V3Slot }> = ({ s }) => {
  const frameW = W * 0.8;
  const bezel = 16;
  const innerW = frameW - bezel * 2;
  return (
    <div
      style={{
        position: 'absolute',
        top: 660,
        left: '50%',
        transform: `translateX(-50%) rotate(${s.tilt}deg)`,
        width: frameW,
        height: H - 660 + 200,
        background: '#2D3436',
        borderRadius: 92,
        borderBottomLeftRadius: 0,
        borderBottomRightRadius: 0,
        padding: bezel,
        boxShadow: '0 40px 120px rgba(45,52,54,0.25)',
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          width: innerW,
          height: '100%',
          borderRadius: 72,
          borderBottomLeftRadius: 0,
          borderBottomRightRadius: 0,
          overflow: 'hidden',
          background: '#fff',
        }}
      >
        <Img
          src={staticFile(`screenshots/${s.file}`)}
          style={{ width: innerW, display: 'block' }}
        />
      </div>
    </div>
  );
};

/** The phone on its side, whole, with the farm on it. */
const Landscape: React.FC<{ s: V3Slot }> = ({ s }) => {
  const frameW = W * 0.94;
  const bezel = 18;
  const innerW = frameW - bezel * 2;
  // iPhone 17 Pro Max on its side: 2868 × 1320.
  const innerH = innerW * (1320 / 2868);
  return (
    <div
      style={{
        position: 'absolute',
        top: 620,
        left: '50%',
        transform: `translateX(-50%) rotate(${s.tilt}deg)`,
        width: frameW,
        height: innerH + bezel * 2,
        background: '#2D3436',
        borderRadius: 96,
        padding: bezel,
        boxShadow: '0 40px 120px rgba(45,52,54,0.25)',
      }}
    >
      <div
        style={{
          width: innerW,
          height: innerH,
          borderRadius: 78,
          overflow: 'hidden',
          background: '#fff',
        }}
      >
        <Img
          src={staticFile(`screenshots/${s.file}`)}
          style={{ width: innerW, height: innerH, display: 'block' }}
        />
      </div>
    </div>
  );
};

export const StoreScreenshotV3: React.FC<
  z.input<typeof storeScreenshotV3Schema>
> = ({ locale, slot }) => {
  const s = storeShotsV3[locale][slot - 1];
  if (!s) throw new Error(`No v3 slot ${slot} for ${locale}`);
  return (
    <AbsoluteFill style={{ background: THEMES[s.theme].bg }}>
      {s.landscape && (
        // A clay hill for the farm's animals to stand on.
        <div
          style={{
            position: 'absolute',
            left: -200,
            right: -200,
            top: 1380,
            bottom: -400,
            borderRadius: '50% 50% 0 0',
            background: 'linear-gradient(180deg, #9ED67A 0%, #7CC05A 100%)',
            boxShadow: 'inset 0 30px 60px rgba(255,255,255,0.35)',
          }}
        />
      )}
      <Headline s={s} />
      {s.landscape ? <Landscape s={s} /> : <Portrait s={s} />}
      {(s.friends ?? []).map((f) => (
        <Friend key={f.name} {...f} />
      ))}
    </AbsoluteFill>
  );
};
